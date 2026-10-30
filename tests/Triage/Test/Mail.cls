Include %occInclude

/// Triage.Util.Mail: addresses, display names, HTML to text, %Net.MailMessage to Triage.Msg.Email; the IMAP adapter's Python parser.
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

/// Embedded Python (python/triage_mail.py): encoded-word subject, quoted-printable UTF-8 body, a base64 attachment.
Method TestParseRawMultipart()
{
    Set crlf = $Char(13, 10)
    Set raw = "From: ""Maria Lopez"" <Maria@ShopCo.example>"_crlf_"To: Triage <triage@triage.local>"_crlf
    Set raw = raw_"Subject: =?UTF-8?B?0KHRh9GR0YI=?="_crlf_"Message-ID: <q1@shopco.example>"_crlf
    Set raw = raw_"Date: Wed, 28 Oct 2026 12:00:00 +0000"_crlf_"MIME-Version: 1.0"_crlf
    Set raw = raw_"Content-Type: multipart/mixed; boundary=""b1"""_crlf_crlf
    Set raw = raw_"--b1"_crlf_"Content-Type: text/plain; charset=utf-8"_crlf_"Content-Transfer-Encoding: quoted-printable"_crlf_crlf
    Set raw = raw_"=D0=9F=D1=80=D0=B8=D0=B2=D0=B5=D1=82"_crlf
    Set raw = raw_"--b1"_crlf_"Content-Type: application/pdf"_crlf_"Content-Disposition: attachment; filename=""invoice.pdf"""_crlf
    Set raw = raw_"Content-Transfer-Encoding: base64"_crlf_crlf_"JVBERi0xLjQK"_crlf_"--b1--"_crlf

    Set item = {}.%FromJSON(##class(Triage.Adapter.IMAPInbound).ParseRaw(raw))
    Do $$$AssertEquals(item.fromAddr, "maria@shopco.example", "address lower-cased")
    Do $$$AssertEquals(item.fromName, "Maria Lopez", "display name without quotes")
    Do $$$AssertEquals(item.to, "triage@triage.local", "first recipient")
    Do $$$AssertEquals(item.subject, $ZConvert($Char(208, 161, 209, 135, 209, 145, 209, 130), "I", "UTF8"), "encoded-word subject decoded")
    Do $$$AssertEquals(item.date, "Wed, 28 Oct 2026 12:00:00 +0000", "date header as received")
    Do $$$AssertEquals(item.attachments, 1, "the PDF counts as an attachment")

    Set msg = ##class(Triage.Util.Mail).FromParsed(item)
    Do $$$AssertEquals(msg.Body, $ZConvert($Char(208, 159, 209, 128, 208, 184, 208, 178, 208, 181, 209, 130), "I", "UTF8"), "quoted-printable UTF-8 body decoded")
    Do $$$AssertEquals(msg.MessageId, "<q1@shopco.example>", "message id")
    Do $$$AssertEquals(msg.Source, "imap", "source")
}

Method TestParseRawHtmlOnly()
{
    Set crlf = $Char(13, 10)
    Set raw = "From: tom@newstartup.example"_crlf_"Subject: Bot?"_crlf_"Content-Type: text/html; charset=utf-8"_crlf_crlf
    Set raw = raw_"<p>Hi Oleg,</p><p>Do you build <b>Telegram bots</b>?</p>"_crlf
    Set msg = ##class(Triage.Util.Mail).FromParsed({}.%FromJSON(##class(Triage.Adapter.IMAPInbound).ParseRaw(raw)))
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
