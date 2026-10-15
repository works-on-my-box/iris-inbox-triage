/// Raises an alert for an urgent email: stores it and, if a webhook is set, posts it there.
Class Triage.Operation.Alert Extends Ens.BusinessOperation
{

/// Optional URL that receives {"text": "..."} for each alert (Slack-style incoming webhook).
Property WebhookURL As %String(MAXLEN = 500);

Parameter SETTINGS = "WebhookURL:Alerts";

Method OnMessage(pRequest As Triage.Msg.Decision, Output pResponse As Ens.Response) As %Status
{
    Set alert = ##class(Triage.Data.Alert).%New()
    Set alert.DecisionId = pRequest.DecisionId
    Set alert.Text = "["_pRequest.Category_"] "_pRequest.Subject_" — from "_pRequest.Sender_". "_pRequest.Reason
    If ..WebhookURL '= "" {
        Set http = ##class(%Net.HttpRequest).%New()
        Set http.ContentType = "application/json"
        Do http.EntityBody.Write({"text": (alert.Text)}.%ToJSON())
        Set sc = http.Post(..WebhookURL)
        Set alert.Delivered = $$$ISOK(sc) && (http.HttpResponse.StatusCode < 300)
        If 'alert.Delivered $$$LOGWARNING("Webhook did not accept the alert")
    }
    Quit alert.%Save()
}

}
