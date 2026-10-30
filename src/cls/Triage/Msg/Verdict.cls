/// What the agent decided about one email; the response of Triage.Operation.Agent.
Class Triage.Msg.Verdict Extends Ens.Response
{

Property Category As %String(MAXLEN = 40);

Property Urgency As %String(MAXLEN = 20);

Property Action As %String(MAXLEN = 40);

Property Reason As %String(MAXLEN = 1000);

Property Confidence As %Numeric(SCALE = 2);

/// agent, or fallback when no decision was recorded
Property DecidedBy As %String(MAXLEN = 20);

Property ToolCalls As %Integer;

Property PromptTokens As %Integer;

Property CompletionTokens As %Integer;

Property LlmMs As %Integer;

/// Model that decided, from the agent class.
Property Model As %String(MAXLEN = 100);

/// CRC-32 of the agent's instructions: which version of the prompt produced this verdict.
Property PromptVersion As %String(MAXLEN = 8);

/// The verdict used when the agent could not decide: a person looks at the email.
ClassMethod Fallback(reason As %String) As Triage.Msg.Verdict
{
    Set v = ..%New()
    Set v.Category = "other", v.Urgency = "normal", v.Action = "review"
    Set v.Reason = reason, v.Confidence = 0, v.DecidedBy = "fallback"
    Return v
}

}
