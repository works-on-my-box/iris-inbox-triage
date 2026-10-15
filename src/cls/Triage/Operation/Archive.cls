/// Closes emails that need nothing from the owner.
Class Triage.Operation.Archive Extends Ens.BusinessOperation
{

Method OnMessage(pRequest As Triage.Msg.Decision, Output pResponse As Ens.Response) As %Status
{
    Set row = ##class(Triage.Data.Decision).%OpenId(pRequest.DecisionId)
    If '$IsObject(row) Quit $$$ERROR($$$GeneralError, "No decision "_pRequest.DecisionId)
    Set row.Status = "archived"
    Quit row.%Save()
}

}
