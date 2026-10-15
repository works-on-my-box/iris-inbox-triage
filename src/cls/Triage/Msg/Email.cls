/// One inbound email, as read from the inbox folder.
Class Triage.Msg.Email Extends Ens.Request
{

Property Sender As %String(MAXLEN = 320);

Property Subject As %String(MAXLEN = 500);

Property Body As %String(MAXLEN = "");

Property FileName As %String(MAXLEN = 500);

Property ReceivedAt As %TimeStamp [ InitialExpression = {$ZDateTime($Horolog, 3)} ];

}
