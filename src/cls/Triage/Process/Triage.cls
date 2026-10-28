/// Asks the agent operation for a verdict, records the decision, and routes it to the operations that act on it.
/// Triage.Process.TriageBPL is the same workflow in BPL; Triage.Inbox.Folder targets this one, Triage.Inbox.Mail the BPL one.
Class Triage.Process.Triage Extends Ens.BusinessProcess
{

/// Decisions below this confidence also go to a person.
Property ReviewBelow As %Numeric [ InitialExpression = 0.6 ];

/// Seconds to wait for the agent, including its retries.
Property AgentTimeout As %Numeric [ InitialExpression = 300 ];

Parameter SETTINGS = "ReviewBelow:Triage,AgentTimeout:Triage";

Method OnRequest(pRequest As Triage.Msg.Email, Output pResponse As Ens.Response) As %Status
{
    Set sc = ..SendRequestSync("Triage.Agent", pRequest, .verdict, ..AgentTimeout)
    If $$$ISERR(sc) || '$IsObject($Get(verdict)) {
        $$$LOGWARNING("No verdict from the agent: "_$System.Status.GetErrorText(sc))
        Set verdict = ##class(Triage.Msg.Verdict).Fallback("The agent did not answer, so a person should look at this email.")
    }
    Set row = ##class(Triage.Data.Decision).Record(pRequest, verdict)
    Set msg = ##class(Triage.Msg.Decision).FromRow(row, pRequest)
    $$$LOGINFO("Triage: "_row.Category_" / "_row.Urgency_" / "_row.Action_" ("_row.Confidence_", "_row.DecidedBy_")")

    If (row.Urgency = "hot") || (row.Action = "alert") $$$ThrowOnError(..SendRequestAsync("Triage.Alert", msg, 0))
    If row.Action = "draft_reply" $$$ThrowOnError(..SendRequestAsync("Triage.Draft", msg, 0))
    If row.Action = "archive" $$$ThrowOnError(..SendRequestAsync("Triage.Archive", msg, 0))
    If (row.Action = "review") || (row.Confidence < ..ReviewBelow) $$$ThrowOnError(..SendRequestAsync("Triage.Review", msg, 0))
    Quit $$$OK
}

}
