/// The triage decision for one email, routed to the operations that act on it.
Class Triage.Msg.Decision Extends Ens.Request
{

Property DecisionId As %Integer;

Property Sender As %String(MAXLEN = 320);

Property SenderName As %String(MAXLEN = 200);

Property Subject As %String(MAXLEN = 500);

Property Body As %String(MAXLEN = "");

Property MessageId As %String(MAXLEN = 500);

Property Category As %String(MAXLEN = 40);

Property Urgency As %String(MAXLEN = 20);

Property Action As %String(MAXLEN = 40);

Property Reason As %String(MAXLEN = 1000);

Property Confidence As %Numeric(SCALE = 2);

ClassMethod FromRow(row As Triage.Data.Decision, email As Triage.Msg.Email) As Triage.Msg.Decision
{
    Set msg = ..%New()
    Set msg.DecisionId = row.%Id()
    For prop = "Sender", "Subject", "Category", "Urgency", "Action", "Reason", "Confidence", "MessageId" {
        Set $Property(msg, prop) = $Property(row, prop)
    }
    Set msg.SenderName = email.SenderName
    Set msg.Body = email.Body
    Return msg
}

}
