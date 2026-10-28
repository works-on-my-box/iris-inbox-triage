/// Reads new mail from a POP3 mailbox (EnsLib.EMail.InboundAdapter) and sends each message to the triage process.
/// Server, port, credentials and TLS are adapter settings; Triage.Setup.Configure fills them from the environment at start.
Class Triage.Service.MailInbox Extends Ens.BusinessService
{

Parameter ADAPTER = "EnsLib.EMail.InboundAdapter";

/// Where parsed emails go.
Property TargetConfigName As Ens.DataType.ConfigName [ InitialExpression = "Triage.Process" ];

Parameter SETTINGS = "TargetConfigName:Basic:selector?multiSelect=0&context={Ens.ContextSearch/ProductionItems?targets=1&productionName=@productionId}";

Method OnProcessInput(pInput As %Net.MailMessage, Output pOutput As %RegisteredObject) As %Status
{
    Try {
        Set msg = ##class(Triage.Util.Mail).FromMailMessage(pInput)
    } Catch ex {
        // A message the parser cannot read still reaches a person instead of staying on the server as an error.
        $$$LOGWARNING("Could not parse mail from "_pInput.From_": "_ex.DisplayString())
        Set msg = ##class(Triage.Msg.Email).%New()
        Set msg.Source = "mail", msg.Sender = ##class(Triage.Util.Mail).Address(pInput.From), msg.Subject = pInput.Subject
    }
    $$$TRACE("Mail from "_msg.Sender_": "_msg.Subject_" ("_$Length(msg.Body)_" chars, "_msg.Attachments_" attachments)")
    Quit ..SendRequestAsync(..TargetConfigName, msg)
}

}
