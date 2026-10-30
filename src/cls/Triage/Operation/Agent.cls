/// Hosts the triage agent: one request per email, the agent's verdict as the response.
/// Provider errors worth waiting out (rate limits, timeouts, server errors) are retried by the operation
/// itself through its RetryInterval and FailureTimeout settings; after that the process falls back to review.
/// The operation also keeps the precedents (Triage.Agent.Precedents): the agent searches them, each email it decides
/// is added, and a decision made by a person in review (a Triage.Msg.Decision from Triage.Review) replaces the agent's.
Class Triage.Operation.Agent Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

/// Precedents knowledge base, opened once per job; empty when it could not be opened (the agent then works without it).
Property Precedents As Triage.Agent.Precedents;

/// A %AI.Agent subclass that records its decision with Triage.Agent.Tools.RecordDecision.
Property AgentClass As %String(MAXLEN = 200) [ InitialExpression = "Triage.Agent.Classifier" ];

/// Characters of the body shown to the agent.
Property MaxBodyChars As %Integer [ InitialExpression = 6000 ];

/// Give the agent the search_precedents tool (IRIS Vector Search over earlier decisions).
Property UsePrecedents As %Boolean [ InitialExpression = 1 ];

Parameter SETTINGS = "AgentClass:Agent,MaxBodyChars:Agent,UsePrecedents:Agent";

XData MessageMap
{
<MapItems>
  <MapItem MessageType="Triage.Msg.Email"><Method>OnMessage</Method></MapItem>
  <MapItem MessageType="Triage.Msg.Decision"><Method>Learn</Method></MapItem>
</MapItems>
}

Method OnInit() As %Status
{
    If ..UsePrecedents {
        Try {
            Set ..Precedents = ##class(Triage.Agent.Precedents).Open()
        } Catch ex {
            $$$LOGWARNING("Precedents are off, the knowledge base did not open: "_ex.DisplayString())
        }
    }
    Quit $$$OK
}

/// A person decided an email in review: its precedent now carries the person's decision.
Method Learn(pRequest As Triage.Msg.Decision, Output pResponse As Ens.Response) As %Status
{
    If '$IsObject(..Precedents) Quit $$$OK
    Quit ..Precedents.Reviewed(pRequest, pRequest.ReviewedBy)
}

Method OnMessage(pRequest As Triage.Msg.Email, Output pResponse As Triage.Msg.Verdict) As %Status
{
    Kill ^||Triage.Decision
    // The audit policy tags every tool call with the email it was made for.
    Set ^||Triage.Email = $ListBuild(pRequest.MessageId, pRequest.Sender)
    Try {
        Set agent = $ClassMethod(..AgentClass, "%New")
        $$$ThrowOnError(agent.%Init())
        If $IsObject(..Precedents) {
            $$$ThrowOnError(..Precedents.KB.AddToAgent(agent))
            // The toolset's own policies do not cover a knowledge-base tool; audit it at the tool manager.
            Set audit = ##class(Triage.Policy.Audit).%New()
            Set audit.ToolPrefix = "search_"
            Do agent.ToolManager.SetAuditPolicy(audit)
        }
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
    Set pResponse.Model = $Parameter(..AgentClass, "MODEL")
    Set pResponse.PromptVersion = ..PromptVersion(..AgentClass)
    If $IsObject(..Precedents) && (pResponse.DecidedBy = "agent") {
        Set sc = ..Precedents.AddDecided(pRequest, pResponse)
        If $$$ISERR(sc) $$$LOGWARNING("Precedent not added: "_$System.Status.GetErrorText(sc))
    }
    Quit $$$OK
}

/// CRC-32 of the INSTRUCTIONS block of an agent class, in hex: changes whenever the prompt is edited.
ClassMethod PromptVersion(agentClass As %String) As %String
{
    Set xdata = ##class(%Dictionary.CompiledXData).%OpenId(agentClass_"||INSTRUCTIONS")
    If '$IsObject(xdata) Return ""
    Set text = ""
    Do xdata.Data.Rewind()
    While 'xdata.Data.AtEnd { Set text = text_xdata.Data.Read(32000) }
    Return $ZHex($ZCRC(text, 7))
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
