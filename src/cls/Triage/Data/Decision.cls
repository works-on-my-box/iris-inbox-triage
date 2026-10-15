/// Every triage decision, kept for the audit trail and as history for later decisions.
Class Triage.Data.Decision Extends %Persistent
{

Property Sender As %String(MAXLEN = 320);

Property SenderDomain As %String(MAXLEN = 200);

Property Subject As %String(MAXLEN = 500);

Property Category As %String(MAXLEN = 40);

Property Urgency As %String(MAXLEN = 20);

Property Action As %String(MAXLEN = 40);

Property Reason As %String(MAXLEN = 1000);

Property Confidence As %Numeric(SCALE = 2);

/// agent, or fallback when the agent could not decide
Property DecidedBy As %String(MAXLEN = 20);

Property DecidedAt As %TimeStamp [ InitialExpression = {$ZDateTime($Horolog, 3)} ];

/// open until an operation or a person closes it
Property Status As %String(MAXLEN = 20) [ InitialExpression = "open" ];

Index SenderIdx On Sender;

Index DomainIdx On SenderDomain;

}
