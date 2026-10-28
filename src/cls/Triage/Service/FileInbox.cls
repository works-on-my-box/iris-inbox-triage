/// Reads emails dropped into the inbox folder as .eml text files and sends each to the triage process.
/// Only the From, To, Subject, Date, Message-ID and Content-Type headers are used; everything after the first blank line is the body
/// (single-part messages only; an HTML body is reduced to text).
/// The mail server service (Triage.Service.MailInbox) is the main entry; this one works offline and in tests.
Class Triage.Service.FileInbox Extends Ens.BusinessService
{

Parameter ADAPTER = "EnsLib.File.InboundAdapter";

/// Where parsed emails go.
Property TargetConfigName As Ens.DataType.ConfigName [ InitialExpression = "Triage.Process" ];

Parameter SETTINGS = "TargetConfigName:Basic:selector?multiSelect=0&context={Ens.ContextSearch/ProductionItems?targets=1&productionName=@productionId}";

Method OnProcessInput(pInput As %Stream.Object, Output pOutput As %RegisteredObject) As %Status
{
    Set msg = ..Parse(pInput)
    Set msg.FileName = pInput.Attributes("Filename")
    Quit ..SendRequestAsync(..TargetConfigName, msg)
}

ClassMethod Parse(stream As %Stream.Object) As Triage.Msg.Email
{
    Set msg = ##class(Triage.Msg.Email).%New()
    Set msg.Source = "folder"
    Set inHeaders = 1
    Set (body, contentType) = ""
    Do stream.Rewind()
    While 'stream.AtEnd {
        Set line = $ZStrip(stream.ReadLine(), ">", $Char(13))
        If inHeaders {
            If line = "" { Set inHeaders = 0 Continue }
            Set name = $ZConvert($Piece(line, ":", 1), "L")
            Set value = $ZStrip($Piece(line, ":", 2, *), "<>W")
            If name = "from" Set msg.Sender = ##class(Triage.Util.Mail).Address(value), msg.SenderName = ##class(Triage.Util.Mail).DisplayName(value)
            If name = "to" Set msg.Recipient = ##class(Triage.Util.Mail).Address(value)
            If name = "subject" Set msg.Subject = value
            If name = "date" Set msg.SentAt = value
            If name = "message-id" Set msg.MessageId = value
            If name = "content-type" Set contentType = $ZConvert(value, "L")
        } Else {
            Set body = body_line_$Char(10)
        }
    }
    If contentType [ "text/html" Set body = ##class(Triage.Util.Mail).StripHtml(body)
    Set msg.Body = $Extract(body, 1, 20000)
    Return msg
}

}
