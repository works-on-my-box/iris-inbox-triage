Include %occInclude

/// Triage.Process.ReviewBPL: the task text the reviewer reads, how the reviewer's choice is recorded and routed, the role.
Class Triage.Test.Review Extends %UnitTest.TestCase
{

Method TestTaskTextFitsTheTask()
{
    Set d = ##class(Triage.Msg.Decision).%New()
    Set d.Sender = "jpark@northbay.example", d.SenderName = "J. Park", d.Subject = "Re: our call"
    Set d.Category = "other", d.Urgency = "normal", d.Action = "review", d.Confidence = 0.4
    Set d.Reason = "Unknown sender refers to a call the history does not show."
    Set d.Body = $Translate($Justify("", 5000), " ", "x")
    Set text = ##class(Triage.Process.ReviewBPL).TaskText(d)
    Do $$$AssertTrue($Length(text) <= 2000, "fits the 2,000-character task message")
    Do $$$AssertTrue(text [ "From: J. Park <jpark@northbay.example>", "sender")
    Do $$$AssertTrue(text [ "Agent: other / normal / review, confidence .4", "the agent's verdict")
    Do $$$AssertTrue(text [ "Reason: Unknown sender", "the agent's reason")
    Do $$$AssertTrue(text [ "xxxx", "the start of the email")
}

Method TestReviewedRecordsTheChoice()
{
    Set email = ##class(Triage.Msg.Email).%New()
    Set email.Sender = "jpark@northbay.example", email.Subject = "Re: our call", email.Body = "Could you send the signed document back by Friday?", email.Source = "folder"
    Set verdict = ##class(Triage.Msg.Verdict).%New()
    Set verdict.Category = "other", verdict.Urgency = "normal", verdict.Action = "review", verdict.Reason = "Unsure who this is.", verdict.Confidence = 0.4, verdict.DecidedBy = "agent"
    Set row = ##class(Triage.Data.Decision).Record(email, verdict)
    Set d = ##class(Triage.Msg.Decision).FromRow(row, email)

    Set routed = ##class(Triage.Process.ReviewBPL).Reviewed(d, "Draft", "_SYSTEM")
    Do $$$AssertTrue($IsObject(routed), "a choice is routed")
    Do $$$AssertEquals(routed.Action, "draft_reply", "Draft maps to draft_reply")
    Do $$$AssertEquals(routed.Body, d.Body, "the routed copy carries the email for the writer")
    Do $$$AssertEquals(d.Action, "review", "the original message keeps the agent's action")
    Set row = ##class(Triage.Data.Decision).%OpenId(row.%Id())
    Do $$$AssertEquals(row.ReviewedBy, "_SYSTEM", "reviewer recorded")
    Do $$$AssertEquals(row.ReviewAction, "draft_reply", "reviewer's action recorded")
    Do $$$AssertEquals(row.Action, "review", "agent's action kept on the row")
    Do $$$AssertEquals(row.Status, "reviewed", "status")
    Do $$$AssertEquals(##class(Triage.Process.ReviewBPL).Reviewed(d, "", "_SYSTEM"), "", "no choice: nothing routed")
    Do ##class(Triage.Data.Decision).%DeleteId(row.%Id())
}

Method TestReviewerRole()
{
    Do $$$AssertTrue(##class(EnsLib.Workflow.RoleDefinition).%ExistsId("Triage Reviewers"), "role exists")
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM EnsLib_Workflow.RoleMembership WHERE RoleName = 'Triage Reviewers' AND UserName = '_SYSTEM'")
    Do $$$AssertTrue(rs.%Next() && (rs.N = 1), "_SYSTEM is a member, so the tasks show in its Workflow Inbox")
}

}
