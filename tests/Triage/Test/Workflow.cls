Include %occInclude

/// The parts of the workflow that run without an LLM: the production definition, the decision record, the retry rule.
Class Triage.Test.Workflow Extends %UnitTest.TestCase
{

Method TestProductionItemsResolve()
{
    Set production = ##class(Ens.Config.Production).%OpenId("Triage.Production")
    Do $$$AssertTrue($IsObject(production), "production definition is loaded")
    Quit:'$IsObject(production)
    Do $$$AssertEquals(production.Items.Count(), 9, "two services, two processes, five operations")
    For i = 1:1:production.Items.Count() {
        Set item = production.Items.GetAt(i)
        Do $$$AssertTrue(##class(%Dictionary.CompiledClass).%ExistsId(item.ClassName), item.Name_" -> "_item.ClassName_" is compiled")
    }
    Do $$$AssertTrue(##class(%Dictionary.CompiledClass).%ExistsId("Triage.Process.TriageBPL.Thread1"), "the BPL compiled into a thread class")
}

Method TestRecordDecisionRow()
{
    Set email = ##class(Triage.Msg.Email).%New()
    Set email.Sender = "Maria@ShopCo.example", email.SenderName = "Maria Lopez", email.Subject = "Weekends?", email.Body = "Does it run on weekends?"
    Set email.MessageId = "<test-row@triage.local>", email.Source = "folder"
    Set verdict = ##class(Triage.Msg.Verdict).%New()
    Set verdict.Category = "client", verdict.Urgency = "normal", verdict.Action = "draft_reply", verdict.Reason = "Known client, simple question.", verdict.Confidence = 0.95, verdict.DecidedBy = "agent"
    Set row = ##class(Triage.Data.Decision).Record(email, verdict)
    Do $$$AssertTrue(row.%Id() > 0, "row saved")
    Do $$$AssertEquals(row.Sender, "maria@shopco.example", "sender lower case")
    Do $$$AssertEquals(row.SenderDomain, "shopco.example", "domain")
    Do $$$AssertEquals(row.Action, "draft_reply", "action copied")
    Do $$$AssertEquals(row.Status, "open", "open until an operation closes it")
    Set msg = ##class(Triage.Msg.Decision).FromRow(row, email)
    Do $$$AssertEquals(msg.DecisionId, row.%Id(), "decision id")
    Do $$$AssertEquals(msg.SenderName, "Maria Lopez", "sender name travels with the message")
    Do $$$AssertEquals(msg.Body, email.Body, "body travels with the message for the draft")
    Do ##class(Triage.Data.Decision).%DeleteId(row.%Id())
}

Method TestFallbackVerdict()
{
    Set v = ##class(Triage.Msg.Verdict).Fallback("no answer")
    Do $$$AssertEquals(v.Action, "review", "a person looks at it")
    Do $$$AssertEquals(v.Confidence, 0, "no confidence")
    Do $$$AssertEquals(v.DecidedBy, "fallback", "marked as fallback")
}

Method TestTransientErrors()
{
    Do $$$AssertEquals(##class(Triage.Operation.Agent).Transient("Provider 'gemini' error: Rate limit exceeded (HTTP 429)"), 1, "rate limit is retried")
    Do $$$AssertEquals(##class(Triage.Operation.Agent).Transient("Request timed out after 60s"), 1, "timeout is retried")
    Do $$$AssertEquals(##class(Triage.Operation.Agent).Transient("HTTP 503 Service Unavailable"), 1, "server error is retried")
    Do $$$AssertEquals(##class(Triage.Operation.Agent).Transient("API key not valid"), 0, "a bad key fails at once")
}

Method TestPromptShowsWhatTheAgentNeeds()
{
    Set email = ##class(Triage.Msg.Email).%New()
    Set email.Sender = "tom@newstartup.example", email.SenderName = "Tom Reed", email.Subject = "Bot?", email.Body = "Do you build bots?", email.Attachments = 2
    Set prompt = ##class(Triage.Operation.Agent).Prompt(email, 6000)
    Do $$$AssertTrue(prompt [ "From: Tom Reed <tom@newstartup.example>", "sender with name")
    Do $$$AssertTrue(prompt [ "Domain: newstartup.example", "domain for the lookups")
    Do $$$AssertTrue(prompt [ "Attachments: 2", "attachment count")
    Do $$$AssertTrue(prompt [ "Do you build bots?", "body")
    Do $$$AssertEquals($Extract(##class(Triage.Operation.Agent).Prompt(email, 5), *-4, *), "Do yo", "body cut to the limit")
}

}
