/// A draft reply written by Triage.Agent.Writer; a person edits and sends it.
Class Triage.Data.Draft Extends %Persistent
{

Property DecisionId As %Integer;

Property Recipient As %String(MAXLEN = 320);

Property Subject As %String(MAXLEN = 500);

Property Body As %String(MAXLEN = "");

/// stored, or mailed when a copy went to the owner's mailbox
Property Status As %String(MAXLEN = 20) [ InitialExpression = "stored" ];

Property CreatedAt As %TimeStamp [ InitialExpression = {$ZDateTime($Horolog, 3)} ];

Index DecisionIdx On DecisionId;

}
