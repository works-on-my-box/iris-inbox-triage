Include %occInclude

/// Triage.Util.Mail: addresses, display names, HTML to text, %Net.MailMessage to Triage.Msg.Email.
Class Triage.Test.Mail Extends %UnitTest.TestCase
{

Method TestAddress()
{
    Do $$$AssertEquals(##class(Triage.Util.Mail).Address("Jane Doe <Jane@Example.com>"), "jane@example.com", "name and brackets removed, lower case")
    Do $$$AssertEquals(##class(Triage.Util.Mail).Address("  a@b.c "), "a@b.c", "bare address trimmed")
}

Method TestDisplayName()
{
    Do $$$AssertEquals(##class(Triage.Util.Mail).DisplayName("Jane Doe <jane@example.com>"), "Jane Doe", "plain name")
    Do $$$AssertEquals(##class(Triage.Util.Mail).DisplayName("""Doe, Jane"" <jane@example.com>"), "Doe, Jane", "quoted name")
    Do $$$AssertEquals(##class(Triage.Util.Mail).DisplayName("jane@example.com"), "", "no name")
}

Method TestStripHtml()
{
    Set html = "<html><head><style>p {color: red}</style></head><body><p>Hi <b>there</b></p><p>Second&nbsp;line &amp; more</p><script>alert(1)</script></body></html>"
    Do $$$AssertEquals(##class(Triage.Util.Mail).StripHtml(html), "Hi there"_$Char(10)_"Second line & more", "tags, style and script removed, block elements break lines, entities decoded")
    Do $$$AssertEquals(##class(Triage.Util.Mail).StripHtml(""), "", "empty stays empty")
}

Method TestFromMailMessageMultipart()
{
    Set mail = ##class(%Net.MailMessage).%New()
    Set mail.From = "Maria Lopez <maria@shopco.example>"
    Do mail.To.Insert("triage@triage.local")
    Set mail.Subject = "Invoice"
    Set mail.Date = "Tue, 28 Oct 2026 12:00:00 +0000"
    Do mail.Headers.SetAt("<abc@shopco.example>", "message-id")
    Set mail.IsMultiPart = 1
    Set text = ##class(%Net.MailMessagePart).%New()
    Do text.TextData.Write("Hello Oleg"_$Char(13, 10)_"second line")
    Do mail.Parts.SetAt(text, 1)
    Set pdf = ##class(%Net.MailMessagePart).%New()
    Set pdf.FileName = "invoice.pdf", pdf.IsBinary = 1
    Do mail.Parts.SetAt(pdf, 2)

    Set msg = ##class(Triage.Util.Mail).FromMailMessage(mail)
    Do $$$AssertEquals(msg.Sender, "maria@shopco.example", "sender address")
    Do $$$AssertEquals(msg.SenderName, "Maria Lopez", "sender name")
    Do $$$AssertEquals(msg.Recipient, "triage@triage.local", "recipient")
    Do $$$AssertEquals(msg.Subject, "Invoice", "subject")
    Do $$$AssertEquals(msg.MessageId, "<abc@shopco.example>", "message id from the lower-case header key")
    Do $$$AssertEquals(msg.Body, "Hello Oleg"_$Char(10)_"second line", "text part, CR removed")
    Do $$$AssertEquals(msg.Attachments, 1, "one attachment")
    Do $$$AssertEquals(msg.Source, "mail", "source")
}

Method TestFromMailMessageHtmlOnly()
{
    Set mail = ##class(%Net.MailMessage).%New()
    Set mail.From = "tom@newstartup.example"
    Set mail.Subject = "Bot?"
    Set mail.IsHTML = 1
    Do mail.TextData.Write("<p>Hi Oleg,</p><p>Do you build <b>Telegram bots</b>?</p>")
    Set msg = ##class(Triage.Util.Mail).FromMailMessage(mail)
    Do $$$AssertEquals(msg.Body, "Hi Oleg,"_$Char(10)_"Do you build Telegram bots?", "HTML-only body reduced to text")
    Do $$$AssertEquals(msg.SenderName, "", "no display name")
    Do $$$AssertEquals(msg.Attachments, 0, "no attachments")
}

Method TestFolderParse()
{
    Set stream = ##class(%Stream.TmpCharacter).%New()
    Do stream.Write("From: Tom Reed <tom@newstartup.example>"_$Char(13, 10)_"To: triage@triage.local"_$Char(13, 10)_"Subject: Bot?"_$Char(13, 10)_"Content-Type: text/html; charset=utf-8"_$Char(13, 10)_$Char(13, 10)_"<p>Hi <i>Oleg</i></p>"_$Char(13, 10))
    Set msg = ##class(Triage.Service.FileInbox).Parse(stream)
    Do $$$AssertEquals(msg.Sender, "tom@newstartup.example", "sender")
    Do $$$AssertEquals(msg.SenderName, "Tom Reed", "sender name")
    Do $$$AssertEquals(msg.Recipient, "triage@triage.local", "recipient")
    Do $$$AssertEquals(msg.Body, "Hi Oleg", "HTML body reduced to text")
    Do $$$AssertEquals(msg.Source, "folder", "source")
}

}
