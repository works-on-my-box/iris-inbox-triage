/// The triage decision for one email, routed to the operations that act on it.
Class Triage.Msg.Decision Extends Ens.Request
{

Property DecisionId As %Integer;

Property Sender As %String(MAXLEN = 320);

Property Subject As %String(MAXLEN = 500);

Property Category As %String(MAXLEN = 40);

Property Urgency As %String(MAXLEN = 20);

Property Action As %String(MAXLEN = 40);

Property Reason As %String(MAXLEN = 1000);

Property Confidence As %Numeric(SCALE = 2);

}
