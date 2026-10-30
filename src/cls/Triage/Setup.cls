Include %occInclude

/// Demo data and runtime configuration.
Class Triage.Setup
{

/// Known contacts for the sample emails. All addresses are made up.
ClassMethod Seed() As %Status
{
    Do ##class(Triage.Data.Contact).%KillExtent()
    $$$ThrowOnError(##class(Triage.Data.Contact).Add("editor@devpress.example", "editor", "Runs the paid technical writing program; two pitches sent in October"))
    $$$ThrowOnError(##class(Triage.Data.Contact).Add("billing@cloudhost.example", "platform", "VPS provider that hosts the owner's automation"))
    $$$ThrowOnError(##class(Triage.Data.Contact).Add("maria@shopco.example", "client", "Small online shop; asked for a price scraper in September"))
    $$$ThrowOnError(##class(Triage.Data.Contact).Add("news@weeklydigest.example", "vendor", "Newsletter the owner subscribed to"))
    Return $$$OK
}

/// Runs when the container starts (after-start.sh): mailbox credentials from MAIL_USER / MAIL_PASSWORD, which inbox service
/// is enabled (MAIL_PROTOCOL: imap, the default, or pop3) and, when MAIL_HOST is set, the server settings of Triage.Inbox.IMAP
/// (MAIL_IMAP_PORT), Triage.Inbox.Mail (MAIL_POP3_PORT), MAIL_TLS=1 for both, and of Triage.Draft (MAIL_SMTP_HOST, MAIL_SMTP_PORT,
/// DRAFTS_TO) — all as system default settings, so the production definition itself stays untouched.
ClassMethod Configure() As %Status
{
    $$$ThrowOnError(##class(Ens.Config.Credentials).SetCredential("TriageMail", ..Env("MAIL_USER", "triage"), ..Env("MAIL_PASSWORD", "triage"), 1))
    // One service reads the mailbox; both reading it would triage every email twice.
    Set pop3 = $ZConvert(..Env("MAIL_PROTOCOL", "imap"), "L") = "pop3"
    Do ..Default("Triage.Inbox.IMAP", "Triage.Service.IMAPInbox", "Enabled", 'pop3)
    Do ..Default("Triage.Inbox.Mail", "Triage.Service.MailInbox", "Enabled", pop3)
    Set host = ..Env("MAIL_HOST", "")
    If host '= "" {
        Set tls = ..Env("MAIL_TLS", "0") = "1"
        If tls $$$ThrowOnError(..EnsureTLS())
        Do ..Default("Triage.Inbox.IMAP", "Triage.Service.IMAPInbox", "IMAPServer", host)
        Do ..Default("Triage.Inbox.IMAP", "Triage.Service.IMAPInbox", "IMAPPort", ..Env("MAIL_IMAP_PORT", $Select(tls: 993, 1: 143)))
        Do ..Default("Triage.Inbox.IMAP", "Triage.Service.IMAPInbox", "UseTLS", tls)
        Do ..Default("Triage.Inbox.Mail", "Triage.Service.MailInbox", "POP3Server", host)
        Do ..Default("Triage.Inbox.Mail", "Triage.Service.MailInbox", "POP3Port", ..Env("MAIL_POP3_PORT", $Select(tls: 995, 1: 110)))
        Do ..Default("Triage.Inbox.Mail", "Triage.Service.MailInbox", "SSLConfig", $Select(tls: "TriageTLS", 1: ""))
        Do ..Default("Triage.Draft", "Triage.Operation.Draft", "SMTPServer", ..Env("MAIL_SMTP_HOST", host))
        Do ..Default("Triage.Draft", "Triage.Operation.Draft", "SMTPPort", ..Env("MAIL_SMTP_PORT", $Select(tls: 465, 1: 25)))
        Do ..Default("Triage.Draft", "Triage.Operation.Draft", "SSLConfig", $Select(tls: "TriageTLS", 1: ""))
        Do ..Default("Triage.Draft", "Triage.Operation.Draft", "From", ..Env("MAIL_USER", "triage"))
        Do ..Default("Triage.Draft", "Triage.Operation.Draft", "Owner", ..Env("DRAFTS_TO", ..Env("MAIL_USER", "")))
    }
    If ##class(Ens.Director).IsProductionRunning() Do ##class(Ens.Director).UpdateProduction()
    Return $$$OK
}

ClassMethod Env(name As %String, default As %String = "") As %String
{
    Set value = $System.Util.GetEnviron(name)
    Return $Select(value = "": default, 1: value)
}

/// One system default setting of the production (Interoperability > Configure > System Default Settings).
ClassMethod Default(item As %String, hostClass As %String, setting As %String, value As %String)
{
    Set row = ##class(Ens.Config.DefaultSettings).%OpenId("Triage.Production||"_item_"||"_hostClass_"||"_setting)
    If '$IsObject(row) {
        Set row = ##class(Ens.Config.DefaultSettings).%New()
        Set row.ProductionName = "Triage.Production", row.ItemName = item, row.HostClassName = hostClass, row.SettingName = setting
    }
    Set row.SettingValue = value, row.Deployable = 1
    $$$ThrowOnError(row.%Save())
}

/// Client TLS configuration for POP3 and SMTP over TLS, verified against the container's CA bundle (the IMAP adapter uses Python's ssl).
ClassMethod EnsureTLS() As %Status
{
    New $Namespace
    Set $Namespace = "%SYS"
    If ##class(Security.SSLConfigs).Exists("TriageTLS") Return $$$OK
    Set p("Type") = 0, p("Enabled") = 1, p("VerifyPeer") = 1, p("CAFile") = "/etc/ssl/certs/ca-certificates.crt"
    Set p("Description") = "Client TLS for the triage mailbox"
    Return ##class(Security.SSLConfigs).Create("TriageTLS", .p)
}

}
