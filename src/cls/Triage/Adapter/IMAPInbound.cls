/// Inbound adapter for IMAP mailboxes (IRIS ships POP3 only), written in Embedded Python: imaplib talks to the server,
/// the email package decodes the message (MIME parts, charsets, encoded-word headers).
/// Each poll fetches up to MaxMessages unseen messages without flagging them, hands each to the business service as a
/// Triage.Msg.Email, and only then flags it \Seen (or deletes it). A message the service did not accept stays unseen
/// for the next poll; a message accepted but not flagged (the connection dropped) is remembered by UID and not sent twice.
Class Triage.Adapter.IMAPInbound Extends Ens.InboundAdapter
{

/// IMAP server, for example imap.gmail.com
Property IMAPServer As %String(MAXLEN = 200) [ InitialExpression = "mail" ];

/// 993 with TLS, 143 without; the test server from docker-compose.yml listens on 3143.
Property IMAPPort As %Integer [ InitialExpression = 3143 ];

/// IMAP over TLS, verified against the system CA bundle.
Property UseTLS As %Boolean [ InitialExpression = 0 ];

Property Mailbox As %String(MAXLEN = 200) [ InitialExpression = "INBOX" ];

/// After a message is processed: 0 flags it \Seen, 1 deletes it.
Property DeleteMessage As %Boolean [ InitialExpression = 0 ];

/// Messages handled per poll.
Property MaxMessages As %Integer(MINVAL = 1) [ InitialExpression = 10 ];

Parameter SETTINGS = "IMAPServer:Basic,IMAPPort:Basic,UseTLS:Basic,Credentials:Basic:credentialsSelector,Mailbox:Basic,DeleteMessage:Basic,MaxMessages:Additional";

Method OnTask() As %Status
{
    Set sc = $$$OK
    Try {
        Set user = ..%CredentialsObj.Username, password = ..%CredentialsObj.Password
        Set batch = {}.%FromJSON(..Fetch(..IMAPServer, ..IMAPPort, ..UseTLS, user, password, ..Mailbox, ..MaxMessages))
        Set key = $ListBuild(..IMAPServer, user, ..Mailbox), validity = batch.uidvalidity
        // A new UIDVALIDITY means the server renumbered the mailbox: the remembered UIDs no longer apply.
        If $Get(^Triage.IMAP(key)) '= validity Kill ^Triage.IMAP(key) Set ^Triage.IMAP(key) = validity
        Set done = []
        Set iter = batch.messages.%GetIterator()
        While iter.%GetNext(, .item) {
            If '$Data(^Triage.IMAP(key, item.uid)) {
                Set sc = ..BusinessHost.ProcessInput(##class(Triage.Util.Mail).FromParsed(item, "imap"))
                Quit:$$$ISERR(sc)
                Set ^Triage.IMAP(key, item.uid) = $ZDateTime($Horolog, 3)
            }
            Do done.%Push(item.uid)
        }
        If done.%Size() {
            Do ..Finish(..IMAPServer, ..IMAPPort, ..UseTLS, user, password, ..Mailbox, done.%ToJSON(), ..DeleteMessage)
            For i = 0:1:done.%Size() - 1 Kill ^Triage.IMAP(key, done.%Get(i))
        }
    } Catch ex {
        Set sc = ex.AsStatus()
    }
    Quit sc
}

/// Unseen messages of the mailbox, decoded: {"uidvalidity": "...", "messages": [{"uid": "...", ...ParseRaw fields}]}.
ClassMethod Fetch(server As %String, port As %Integer, tls As %Boolean, user As %String, password As %String, mailbox As %String, max As %Integer) As %String [ Language = python ]
{
    import imaplib, json, ssl, triage_mail
    conn = imaplib.IMAP4_SSL(server, port, ssl_context=ssl.create_default_context()) if tls else imaplib.IMAP4(server, port)
    try:
        conn.login(user, password)
        typ, _ = conn.select(mailbox)
        if typ != "OK":
            raise RuntimeError(f"cannot open mailbox {mailbox!r}")
        validity = (conn.response("UIDVALIDITY")[1] or [b""])[0].decode()
        typ, data = conn.uid("search", None, "UNSEEN")
        messages = []
        for uid in data[0].split()[:max]:
            typ, parts = conn.uid("fetch", uid, "(BODY.PEEK[])")
            raw = next((p[1] for p in parts if isinstance(p, tuple)), None)
            if raw is None:
                continue
            # Parsed here, in Python: the raw message (attachments included) never becomes an IRIS string.
            item = triage_mail.parse(raw)
            item["uid"] = uid.decode()
            messages.append(item)
        return json.dumps({"uidvalidity": validity, "messages": messages})
    finally:
        try:
            conn.logout()
        except Exception:
            pass
}

/// Flags the processed messages \Seen, or deletes them; uids is a JSON array.
ClassMethod Finish(server As %String, port As %Integer, tls As %Boolean, user As %String, password As %String, mailbox As %String, uids As %String, delete As %Boolean) [ Language = python ]
{
    import imaplib, json, ssl
    conn = imaplib.IMAP4_SSL(server, port, ssl_context=ssl.create_default_context()) if tls else imaplib.IMAP4(server, port)
    try:
        conn.login(user, password)
        conn.select(mailbox)
        uid_set = ",".join(json.loads(uids))
        conn.uid("store", uid_set, "+FLAGS", "(\\Deleted)" if delete else "(\\Seen)")
        if delete:
            conn.expunge()
    finally:
        try:
            conn.logout()
        except Exception:
            pass
}

/// Decodes one RFC 822 message with python/triage_mail.py; raw holds its bytes, one character per byte.
/// Returns JSON: fromName, fromAddr, to, subject, date, messageId, text, html, attachments.
ClassMethod ParseRaw(raw As %String) As %String [ Language = python ]
{
    import json, triage_mail
    return json.dumps(triage_mail.parse(raw.encode("latin-1")))
}

}
