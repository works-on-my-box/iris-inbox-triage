Include %occInclude

/// Triage.Agent.Tools: RecordDecision (validation and the hand-over to the operation) and LookupContact, run as the agent runs it.
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

/// A contact at a shared mail provider is known by its address only: another gmail.com sender is not a known contact.
Method TestLookupContactByDomain()
{
    Set tools = ##class(Triage.Agent.Tools).%New()
    Set friend = "friend"_$Job_"@gmail.com", boss = "boss"_$Job_"@acme-unit-test.example"
    Do $$$AssertStatusOK(##class(Triage.Data.Contact).Add(friend, "personal", "unit test"), "a contact at gmail.com")
    Do $$$AssertStatusOK(##class(Triage.Data.Contact).Add(boss, "client", "unit test"), "a contact at a company domain")
    Set r = tools.%Invoke("LookupContact", {"address": "stranger@gmail.com", "domain": "gmail.com"})
    Do $$$AssertEquals(r.%Get("row_count"), 0, "another gmail.com sender is not a known contact")
    Set r = tools.%Invoke("LookupContact", {"address": (friend), "domain": "gmail.com"})
    Do $$$AssertEquals(r.%Get("row_count"), 1, "the contact at gmail.com is found by its address")
    Set r = tools.%Invoke("LookupContact", {"address": "someone@acme-unit-test.example", "domain": "acme-unit-test.example"})
    Do $$$AssertEquals(r.%Get("row_count"), 1, "a company domain still matches")
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM Triage_Data.Contact WHERE Address IN (?, ?)", friend, boss)
}

}
