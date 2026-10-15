/// Puts an email in front of a person: the decision stays open in the review queue.
Class Triage.Operation.Review Extends Ens.BusinessOperation
{

Method OnMessage(pRequest As Triage.Msg.Decision, Output pResponse As Ens.Response) As %Status
{
    Set row = ##class(Triage.Data.Decision).%OpenId(pRequest.DecisionId)
    If '$IsObject(row) Quit $$$ERROR($$$GeneralError, "No decision "_pRequest.DecisionId)
    Set row.Status = "review"
    Quit row.%Save()
}

}
