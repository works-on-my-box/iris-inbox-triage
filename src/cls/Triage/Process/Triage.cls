/// Asks the triage agent for a decision, stores it, and routes it to the operations that act on it.
Class Triage.Process.Triage Extends Ens.BusinessProcess
{

/// Decisions below this confidence also go to a person.
Property ReviewBelow As %Numeric [ InitialExpression = 0.6 ];

Parameter SETTINGS = "ReviewBelow:Triage";

Method OnRequest(pRequest As Triage.Msg.Email, Output pResponse As Ens.Response) As %Status
{
    Set decision = ..Decide(pRequest)
    Set row = ##class(Triage.Data.Decision).%New()
    Set row.Sender = $ZConvert(pRequest.Sender, "L")
    Set row.SenderDomain = $ZConvert($Piece(pRequest.Sender, "@", 2), "L")
    Set row.Subject = pRequest.Subject
    Set row.Category = $List(decision, 1)
    Set row.Urgency = $List(decision, 2)
    Set row.Action = $List(decision, 3)
    Set row.Reason = $List(decision, 4)
    Set row.Confidence = $List(decision, 5)
    Set row.DecidedBy = $List(decision, 6)
    $$$ThrowOnError(row.%Save())

    Set msg = ##class(Triage.Msg.Decision).%New()
    For prop = "Sender", "Subject", "Category", "Urgency", "Action", "Reason", "Confidence" {
        Set $Property(msg, prop) = $Property(row, prop)
    }
    Set msg.DecisionId = row.%Id()
    $$$LOGINFO("Triage: "_row.Category_" / "_row.Urgency_" / "_row.Action_" ("_row.Confidence_", "_row.DecidedBy_")")

    If row.Urgency = "hot" || (row.Action = "alert") $$$ThrowOnError(..SendRequestAsync("Triage.Alert", msg, 0))
    If row.Action = "review" || (row.Confidence < ..ReviewBelow) $$$ThrowOnError(..SendRequestAsync("Triage.Review", msg, 0))
    If row.Action = "draft_reply" $$$ThrowOnError(..SendRequestAsync("Triage.Review", msg, 0))
    If row.Action = "archive" $$$ThrowOnError(..SendRequestAsync("Triage.Archive", msg, 0))
    Quit $$$OK
}

/// Runs the agent on one email. Returns $ListBuild(category, urgency, action, reason, confidence, decidedBy).
/// If the agent fails or records nothing, the email goes to a person instead of being dropped.
Method Decide(email As Triage.Msg.Email) As %List
{
    Kill ^||Triage.Decision
    Try {
        Set agent = ##class(Triage.Agent.Classifier).%New()
        $$$ThrowOnError(agent.%Init())
        Set session = agent.CreateSession({"max_iterations": 8, "temperature": 0})
        Set prompt = "From: "_email.Sender_$Char(10)_"Domain: "_$Piece(email.Sender, "@", 2)_$Char(10)_"Subject: "_email.Subject_$Char(10,10)_$Extract(email.Body, 1, 6000)
        Do agent.Chat(session, prompt)
    } Catch ex {
        $$$LOGWARNING("Triage agent failed: "_ex.DisplayString())
    }
    If $Data(^||Triage.Decision, d) Return d_$ListBuild("agent")
    Return $ListBuild("other", "normal", "review", "The agent did not record a decision, so a person should look at this email.", 0, "fallback")
}

}
