/// Turns a %Net.MailMessage from the POP3 adapter into the triage request:
/// the headers, the plain text of the body (HTML stripped when there is no text part) and the attachment count.
Class Triage.Util.Mail
{

ClassMethod FromMailMessage(mail As %Net.MailMessage) As Triage.Msg.Email
{
    Set msg = ##class(Triage.Msg.Email).%New()
    Set msg.Source = "mail"
    Set msg.Sender = ..Address(mail.From)
    Set msg.SenderName = ..DisplayName(mail.From)
    Set msg.Recipient = $Select(mail.To.Count() > 0: ..Address(mail.To.GetAt(1)), 1: "")
    Set msg.Subject = mail.Subject
    Set msg.MessageId = mail.Headers.GetAt("message-id")
    Set msg.SentAt = mail.Date
    Set (text, html) = "", attachments = 0
    Do ..Walk(mail, .text, .html, .attachments)
    If text = "" Set text = ..StripHtml(html)
    Set msg.Body = $Extract(text, 1, 20000)
    Set msg.Attachments = attachments
    Return msg
}

/// The triage request from a message decoded in Python (python/triage_mail.py, via Triage.Adapter.IMAPInbound).
ClassMethod FromParsed(item As %DynamicObject, source As %String = "imap") As Triage.Msg.Email
{
    Set msg = ##class(Triage.Msg.Email).%New()
    Set msg.Source = source
    Set msg.Sender = item.fromAddr, msg.SenderName = item.fromName, msg.Recipient = item.to
    Set msg.Subject = item.subject, msg.MessageId = item.messageId, msg.SentAt = item.date
    Set text = $Translate(item.text, $Char(13), "")
    If $ZStrip(text, "<>WC") = "" Set text = ..StripHtml($Translate(item.html, $Char(13), ""))
    Set msg.Body = $Extract(text, 1, 20000)
    Set msg.Attachments = item.attachments
    Return msg
}

/// Finds the first text part and the first HTML part, counts the attachments; recursive for multipart messages.
ClassMethod Walk(part As %Net.MailMessagePart, ByRef text As %String, ByRef html As %String, ByRef attachments As %Integer)
{
    If part.IsMultiPart {
        Set key = ""
        For {
            Set sub = part.Parts.GetNext(.key)
            Quit:key=""
            Do ..Walk(sub, .text, .html, .attachments)
        }
        Return
    }
    If (part.FileName '= "") || part.IsBinary {
        Set attachments = attachments + 1
        Return
    }
    If part.IsHTML {
        If html = "" Set html = ..ReadAll(part.TextData)
    } ElseIf text = "" {
        Set text = ..ReadAll(part.TextData)
    }
}

ClassMethod ReadAll(stream As %Stream.Object) As %String
{
    If '$IsObject(stream) Return ""
    Do stream.Rewind()
    Set out = ""
    While 'stream.AtEnd {
        Set out = out_stream.Read(32000)
        Quit:$Length(out)>200000
    }
    Return $Translate(out, $Char(13), "")
}

/// Text of an HTML body: tags removed, line breaks kept for block elements, common entities decoded.
ClassMethod StripHtml(html As %String) As %String
{
    If html = "" Return ""
    Set s = ##class(%Regex.Matcher).%New("(?is)<(script|style)[^>]*>.*?</\1>", html).ReplaceAll("")
    Set s = ##class(%Regex.Matcher).%New("(?i)<br\s*/?>|</(p|div|li|tr|h[1-6])>", s).ReplaceAll($Char(10))
    Set s = ##class(%Regex.Matcher).%New("<[^>]+>", s).ReplaceAll("")
    For pair = "&nbsp; ", "&lt;<", "&gt;>", "&quot;""", "&#39;'", "&amp;&" {
        Set s = $Replace(s, $Piece(pair, ";", 1)_";", $Piece(pair, ";", 2, *))
    }
    Set s = ##class(%Regex.Matcher).%New("[ \t]+", s).ReplaceAll(" ")
    Set s = ##class(%Regex.Matcher).%New(" ?\n ?", s).ReplaceAll($Char(10))
    Set s = ##class(%Regex.Matcher).%New("\n{3,}", s).ReplaceAll($Char(10, 10))
    Return $ZStrip(s, "<>WC")
}

/// "Jane Doe <jane@example.com>" -> "jane@example.com"
ClassMethod Address(value As %String) As %String
{
    If value [ "<" Set value = $Piece($Piece(value, "<", 2), ">", 1)
    Return $ZConvert($ZStrip(value, "<>W"), "L")
}

/// "Jane Doe <jane@example.com>" -> "Jane Doe"; empty when the header is only an address
ClassMethod DisplayName(value As %String) As %String
{
    If value '[ "<" Return ""
    Return $ZStrip($Translate($Piece(value, "<", 1), """", ""), "<>W")
}

}
