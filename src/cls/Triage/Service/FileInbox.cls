/// Reads emails dropped into the inbox folder as .eml text files and sends each to the triage process.
/// Only the From and Subject headers are used; everything after the first blank line is the body.
Class Triage.Service.FileInbox Extends Ens.BusinessService
{

Parameter ADAPTER = "EnsLib.File.InboundAdapter";

Method OnProcessInput(pInput As %Stream.Object, Output pOutput As %RegisteredObject) As %Status
{
    Set msg = ..Parse(pInput)
    Set msg.FileName = pInput.Attributes("Filename")
    Quit ..SendRequestAsync("Triage.Process", msg)
}

ClassMethod Parse(stream As %Stream.Object) As Triage.Msg.Email
{
    Set msg = ##class(Triage.Msg.Email).%New()
    Set inHeaders = 1
    Set body = ""
    Do stream.Rewind()
    While 'stream.AtEnd {
        Set line = $ZStrip(stream.ReadLine(), ">", $Char(13))
        If inHeaders {
            If line = "" { Set inHeaders = 0 Continue }
            Set name = $ZConvert($Piece(line, ":", 1), "L")
            Set value = $ZStrip($Piece(line, ":", 2, *), "<>W")
            If name = "from" Set msg.Sender = ..Address(value)
            If name = "subject" Set msg.Subject = value
        } Else {
            Set body = body_line_$Char(10)
        }
    }
    Set msg.Body = $Extract(body, 1, 20000)
    Return msg
}

/// "Jane Doe <jane@example.com>" -> "jane@example.com"
ClassMethod Address(value As %String) As %String
{
    If value [ "<" Set value = $Piece($Piece(value, "<", 2), ">", 1)
    Return $ZConvert($ZStrip(value, "<>W"), "L")
}

}
