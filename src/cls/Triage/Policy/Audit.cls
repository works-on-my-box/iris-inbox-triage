Include %AI

/// Audit policy: every tool call of the triage agent is written to Triage_Data.ToolCall, tagged with the email it was made for.
/// Attached declaratively in Triage.Agent.Tools (the Policies block), so it applies wherever that toolset is used.
Class Triage.Policy.Audit Extends (%AI.Policy.Audit, %XML.Adaptor)
{

Parameter XMLNAME = "Audit";

/// Characters of the tool result kept in the log.
Property PreviewChars As %Integer(XMLPROJECTION = "ELEMENT") [ InitialExpression = 300 ];

Method %LogExecution(call As %DynamicObject, metadata As %DynamicObject, result As %DynamicObject, duration As %Integer, status As %Status) As %Status
{
    Try {
        Set row = ##class(Triage.Data.ToolCall).%New()
        Set row.ToolName = call.name
        Set row.Arguments = $Select($IsObject(call.arguments): call.arguments.%ToJSON(), 1: call.arguments)
        Set row.DurationMs = duration
        Set row.Success = $$$ISOK(status)
        If $IsObject(result) Set row.Result = $Extract(result.%ToJSON(), 1, ..PreviewChars)
        If $$$ISERR(status) Set row.Error = $Extract($System.Status.GetErrorText(status), 1, 1000)
        Set email = $Get(^||Triage.Email)
        Set row.MessageId = $ListGet(email, 1), row.Sender = $ListGet(email, 2)
        Do row.%Save()
    } Catch ex {
        // Auditing must never break the tool call itself.
    }
    Return $$$OK
}

}
