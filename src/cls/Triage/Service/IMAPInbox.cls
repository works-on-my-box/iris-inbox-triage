/// Reads new mail from an IMAP mailbox (Triage.Adapter.IMAPInbound, Embedded Python) and sends each message to the triage process.
/// Server, port, TLS and credentials are adapter settings; Triage.Setup.Configure fills them from the environment at start.
Class Triage.Service.IMAPInbox Extends Ens.BusinessService
{

Parameter ADAPTER = "Triage.Adapter.IMAPInbound";

/// Where parsed emails go.
Property TargetConfigName As Ens.DataType.ConfigName [ InitialExpression = "Triage.ProcessBPL" ];

Parameter SETTINGS = "TargetConfigName:Basic:selector?multiSelect=0&context={Ens.ContextSearch/ProductionItems?targets=1&productionName=@productionId}";

Method OnProcessInput(pInput As Triage.Msg.Email, Output pOutput As %RegisteredObject) As %Status
{
    $$$TRACE("Mail from "_pInput.Sender_": "_pInput.Subject_" ("_$Length(pInput.Body)_" chars, "_pInput.Attachments_" attachments)")
    Quit ..SendRequestAsync(..TargetConfigName, pInput)
}

}
