/// An alert raised for an urgent email; a webhook or chat bot can pick these up.
Class Triage.Data.Alert Extends %Persistent
{

Property DecisionId As %Integer;

Property Text As %String(MAXLEN = 2000);

Property CreatedAt As %TimeStamp [ InitialExpression = {$ZDateTime($Horolog, 3)} ];

Property Delivered As %Boolean [ InitialExpression = 0 ];

}
