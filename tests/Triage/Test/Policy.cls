Include %occInclude

/// The two policies attached to the toolset: one decision per email, and the audit log of tool calls.
Class Triage.Test.Policy Extends %UnitTest.TestCase
{

Method TestOneDecisionPerEmail()
{
    Kill ^||Triage.Decision
    Set policy = ##class(Triage.Policy.OneDecision).%New()
    Set call = {"name": "RecordDecision", "arguments": {}}
    Do $$$AssertStatusOK(policy.%CanExecute("iris:Triage.Agent.Tools", call, {}), "first RecordDecision allowed")
    Set ^||Triage.Decision = $ListBuild("spam", "low", "archive", "x", 1)
    Do $$$AssertStatusNotOK(policy.%CanExecute("iris:Triage.Agent.Tools", call, {}), "second RecordDecision denied")
    Do $$$AssertStatusOK(policy.%CanExecute("iris:Triage.Agent.Tools", {"name": "LookupContact", "arguments": {}}, {}), "lookups stay allowed")
    Kill ^||Triage.Decision
}

Method TestAuditWritesOneRowPerCall()
{
    Set ^||Triage.Email = $ListBuild("<test-audit@triage.local>", "a@b.c")
    Set before = ..Count()
    Set policy = ##class(Triage.Policy.Audit).%New()
    Set call = {"name": "LookupContact", "arguments": {"address": "a@b.c", "domain": "b.c"}}
    Do $$$AssertStatusOK(policy.%LogExecution(call, {}, {"rows": [], "row_count": 0}, 7, $$$OK), "returns a status")
    Do $$$AssertEquals(..Count(), before + 1, "one row written")
    Set row = ##class(Triage.Data.ToolCall).%OpenId(..LastId())
    Do $$$AssertEquals(row.ToolName, "LookupContact", "tool name")
    Do $$$AssertEquals(row.Arguments, "{""address"":""a@b.c"",""domain"":""b.c""}", "arguments as JSON")
    Do $$$AssertEquals(row.MessageId, "<test-audit@triage.local>", "tagged with the email")
    Do $$$AssertEquals(row.Sender, "a@b.c", "tagged with the sender")
    Do $$$AssertEquals(row.DurationMs, 7, "duration")
    Do $$$AssertEquals(row.Success, 1, "success")
    Do ##class(Triage.Data.ToolCall).%DeleteId(row.%Id())
    Kill ^||Triage.Email
}

Method TestAuditKeepsTheError()
{
    Set before = ..Count()
    Set policy = ##class(Triage.Policy.Audit).%New()
    Do policy.%LogExecution({"name": "RecordDecision", "arguments": {}}, {}, {}, 1, $$$ERROR($$$GeneralError, "denied for the test"))
    Do $$$AssertEquals(..Count(), before + 1, "one row written")
    Set row = ##class(Triage.Data.ToolCall).%OpenId(..LastId())
    Do $$$AssertEquals(row.Success, 0, "not a success")
    Do $$$AssertTrue(row.Error [ "denied for the test", "error text kept")
    Do ##class(Triage.Data.ToolCall).%DeleteId(row.%Id())
}

ClassMethod Count() As %Integer
{
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM Triage_Data.ToolCall")
    Do rs.%Next()
    Return rs.N
}

ClassMethod LastId() As %Integer
{
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT MAX(ID) AS M FROM Triage_Data.ToolCall")
    Do rs.%Next()
    Return rs.M
}

}
