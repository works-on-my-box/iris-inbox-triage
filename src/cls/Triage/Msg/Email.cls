/// One inbound email, as read from the mail server or the inbox folder.
Class Triage.Msg.Email Extends Ens.Request
{

Property Sender As %String(MAXLEN = 320);

Property SenderName As %String(MAXLEN = 200);

Property Recipient As %String(MAXLEN = 320);

Property Subject As %String(MAXLEN = 500);

/// Plain text of the message; HTML-only mail is reduced to its text.
Property Body As %String(MAXLEN = "");

Property MessageId As %String(MAXLEN = 500);

/// The Date header as received.
Property SentAt As %String(MAXLEN = 100);

/// imap (IMAP adapter), mail (POP3 adapter) or folder (.eml files)
Property Source As %String(MAXLEN = 20);

Property Attachments As %Integer [ InitialExpression = 0 ];

Property FileName As %String(MAXLEN = 500);

Property ReceivedAt As %TimeStamp [ InitialExpression = {$ZDateTime($Horolog, 3)} ];

}
