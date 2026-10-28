Include %occInclude

/// Every triage decision, kept for the audit trail and as history for later decisions.
Class Triage.Data.Decision Extends %Persistent
{

Property Sender As %String(MAXLEN = 320);

Property SenderDomain As %String(MAXLEN = 200);

Property Subject As %String(MAXLEN = 500);

Property MessageId As %String(MAXLEN = 500);

/// mail or folder
Property Source As %String(MAXLEN = 20);

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

ClassMethod Record(email As Triage.Msg.Email, verdict As Triage.Msg.Verdict) As Triage.Data.Decision
{
    Set row = ..%New()
    Set row.Sender = $ZConvert(email.Sender, "L")
    Set row.SenderDomain = $ZConvert($Piece(email.Sender, "@", 2), "L")
    Set row.Subject = email.Subject
    Set row.MessageId = email.MessageId
    Set row.Source = email.Source
    For prop = "Category", "Urgency", "Action", "Reason", "Confidence", "DecidedBy" {
        Set $Property(row, prop) = $Property(verdict, prop)
    }
    $$$ThrowOnError(row.%Save())
    Return row
}

}
