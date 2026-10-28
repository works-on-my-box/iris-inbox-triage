/// Hosts the triage agent: one request per email, the agent's verdict as the response.
/// Provider errors worth waiting out (rate limits, timeouts, server errors) are retried by the operation
/// itself through its RetryInterval and FailureTimeout settings; after that the process falls back to review.
Class Triage.Operation.Agent Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

/// A %AI.Agent subclass that records its decision with Triage.Agent.Tools.RecordDecision.
Property AgentClass As %String(MAXLEN = 200) [ InitialExpression = "Triage.Agent.Classifier" ];

/// Characters of the body shown to the agent.
Property MaxBodyChars As %Integer [ InitialExpression = 6000 ];

Parameter SETTINGS = "AgentClass:Agent,MaxBodyChars:Agent";

Method OnMessage(pRequest As Triage.Msg.Email, Output pResponse As Triage.Msg.Verdict) As %Status
{
    Kill ^||Triage.Decision
    Try {
        Set agent = $ClassMethod(..AgentClass, "%New")
        $$$ThrowOnError(agent.%Init())
        Set session = agent.CreateSession({"max_iterations": 8, "temperature": 0})
        Do agent.Chat(session, ..Prompt(pRequest, ..MaxBodyChars))
        Set stats = session.GetStats()
    } Catch ex {
        Set text = ex.DisplayString()
        Set ..Retry = ..Transient(text)
        Return $$$ERROR($$$EnsErrGeneral, "Triage agent failed: "_text)
    }
    If $Data(^||Triage.Decision, d) {
        Set pResponse = ##class(Triage.Msg.Verdict).%New()
        Set pResponse.Category = $List(d, 1), pResponse.Urgency = $List(d, 2), pResponse.Action = $List(d, 3)
        Set pResponse.Reason = $List(d, 4), pResponse.Confidence = $List(d, 5), pResponse.DecidedBy = "agent"
    } Else {
        Set pResponse = ##class(Triage.Msg.Verdict).Fallback("The agent did not record a decision, so a person should look at this email.")
    }
    Set pResponse.ToolCalls = stats.%Get("total_tool_calls")
    Set pResponse.PromptTokens = stats.%Get("total_prompt_tokens")
    Set pResponse.CompletionTokens = stats.%Get("total_completion_tokens")
    Set pResponse.LlmMs = stats.%Get("total_llm_duration_ms")
    Quit $$$OK
}

/// Rate limits, timeouts and server errors are retried; anything else (a bad key, a bug) fails at once.
ClassMethod Transient(text As %String) As %Boolean
{
    Set t = $ZConvert(text, "L")
    For needle = "rate limit", "429", "timed out", "timeout", "502", "503", "504", "overloaded", "unavailable", "connection" {
        If t [ needle Return 1
    }
    Return 0
}

ClassMethod Prompt(email As Triage.Msg.Email, maxChars As %Integer = 6000) As %String
{
    Set from = $Select(email.SenderName = "": email.Sender, 1: email.SenderName_" <"_email.Sender_">")
    Return "From: "_from_$Char(10)_"Domain: "_$Piece(email.Sender, "@", 2)_$Char(10)_"Subject: "_email.Subject_$Char(10)_"Attachments: "_email.Attachments_$Char(10, 10)_$Extract(email.Body, 1, maxChars)
}

}
