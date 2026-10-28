Include %occInclude

/// Triage.Agent.Tools.RecordDecision: validation and the hand-over to the operation.
Class Triage.Test.Tools Extends %UnitTest.TestCase
{

Method OnBeforeOneTest(testname As %String) As %Status
{
    Kill ^||Triage.Decision
    Return $$$OK
}

Method TestRecordsValidDecision()
{
    Set reply = ##class(Triage.Agent.Tools).RecordDecision(" Client ", "HOT", "alert", "A known client asks for paid work.", 0.9)
    Do $$$AssertEquals(reply, "Recorded.", "accepted")
    Do $$$AssertTrue($Data(^||Triage.Decision) > 0, "decision handed to the process")
    Do $$$AssertEquals($ListGet(^||Triage.Decision, 1), "client", "category normalized")
    Do $$$AssertEquals($ListGet(^||Triage.Decision, 2), "hot", "urgency normalized")
    Do $$$AssertEquals($ListGet(^||Triage.Decision, 3), "alert", "action")
    Do $$$AssertEquals($ListGet(^||Triage.Decision, 5), 0.9, "confidence")
}

Method TestRejectsUnknownValues()
{
    Do $$$AssertTrue(##class(Triage.Agent.Tools).RecordDecision("urgent", "hot", "alert", "x", 1) [ "category must be one of", "unknown category")
    Do $$$AssertTrue(##class(Triage.Agent.Tools).RecordDecision("client", "asap", "alert", "x", 1) [ "urgency must be one of", "unknown urgency")
    Do $$$AssertTrue(##class(Triage.Agent.Tools).RecordDecision("client", "hot", "reply", "x", 1) [ "action must be one of", "unknown action")
    Do $$$AssertEquals($Data(^||Triage.Decision), 0, "nothing recorded")
}

Method TestClampsConfidenceAndTrimsReason()
{
    Do ##class(Triage.Agent.Tools).RecordDecision("spam", "low", "archive", $Translate($Justify("", 1200), " ", "x"), 1.7)
    Do $$$AssertEquals($ListGet(^||Triage.Decision, 5), 1, "confidence capped at 1")
    Do $$$AssertEquals($Length($ListGet(^||Triage.Decision, 4)), 1000, "reason cut to 1000 characters")
    Do ##class(Triage.Agent.Tools).RecordDecision("spam", "low", "archive", "x", -0.2)
    Do $$$AssertEquals($ListGet(^||Triage.Decision, 5), 0, "confidence floored at 0")
}

}
