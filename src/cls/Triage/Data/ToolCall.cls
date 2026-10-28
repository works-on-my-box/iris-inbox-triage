/// One tool call made by the agent, written by Triage.Policy.Audit.
Class Triage.Data.ToolCall Extends %Persistent
{

Property CalledAt As %TimeStamp [ InitialExpression = {$ZDateTime($Horolog, 3)} ];

/// The email the agent was working on.
Property MessageId As %String(MAXLEN = 500);

Property Sender As %String(MAXLEN = 320);

Property ToolName As %String(MAXLEN = 100);

/// Arguments as JSON
Property Arguments As %String(MAXLEN = "");

/// Start of the result as JSON
Property Result As %String(MAXLEN = 2000);

Property DurationMs As %Integer;

Property Success As %Boolean;

Property Error As %String(MAXLEN = 1000);

Index MessageIdIdx On MessageId;

}
