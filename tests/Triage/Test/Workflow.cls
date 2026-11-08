Include %occInclude

/// The parts of the workflow that run without an LLM: the production definition, the decision record, the retry rule.
Class Triage.Test.Workflow Extends %UnitTest.TestCase
{

Method TestProductionItemsResolve()
{
    Set production = ##class(Ens.Config.Production).%OpenId("Triage.Production")
    Do $$$AssertTrue($IsObject(production), "production definition is loaded")
    Quit:'$IsObject(production)
    Do $$$AssertEquals(production.Items.Count(), 12, "three services (IMAP, POP3, folder), three processes (two triage, one review), six operations (four, the Java export, plus the workflow one)")
    For i = 1:1:production.Items.Count() {
        Set item = production.Items.GetAt(i)
        Do $$$AssertTrue(##class(%Dictionary.CompiledClass).%ExistsId(item.ClassName), item.Name_" -> "_item.ClassName_" is compiled")
    }
    Do $$$AssertTrue(##class(%Dictionary.CompiledClass).%ExistsId("Triage.Process.TriageBPL.Thread1"), "the BPL compiled into a thread class")
}

Method TestFolderInboxOnlyWithItsDirectory()
{
    Do $$$AssertStatusOK(##class(Triage.Setup).Configure(), "configuration applied")
    Set row = ##class(Ens.Config.DefaultSettings).%OpenId("Triage.Production||Triage.Inbox.Folder||Triage.Service.FileInbox||Enabled")
    Do $$$AssertTrue($IsObject(row), "Enabled is a system default of the folder service")
    Do $$$AssertEquals(+row.SettingValue, ##class(%File).DirectoryExists("/data/inbox"), "on where /data/inbox exists, off after an IPM install")
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

Method TestPromptVersion()
{
    Set v = ##class(Triage.Operation.Agent).PromptVersion("Triage.Agent.Classifier")
    Do $$$AssertTrue(v ? 1.8AN, "the classifier's instructions have a CRC-32 version: "_v)
    Do $$$AssertEquals(##class(Triage.Operation.Agent).PromptVersion("Triage.Agent.Classifier"), v, "stable while the prompt is unchanged")
    Do $$$AssertEquals(##class(Triage.Operation.Agent).PromptVersion("No.Such.Agent"), "", "no instructions, no version")
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

/// A BPL switch runs only its first true case, so review for a low confidence is a step of its own after the switch:
/// an archive or a draft decided below ReviewBelow also reaches a person, as in Triage.Process.Triage.
Method TestBPLReviewsLowConfidence()
{
    Set bpl = ##class(%Dictionary.CompiledXData).%OpenId("Triage.Process.TriageBPL||BPL").Data.Read(1000000)
    Set switch = $Piece($Piece(bpl, "<switch", 2), "</switch>", 1)
    Do $$$AssertTrue(switch '[ "Triage.Review", "the review call is not a case of the action switch")
    Set after = $Piece(bpl, "</switch>", 2)
    Do $$$AssertTrue((after [ "process.ReviewBelow") && (after [ "target='Triage.Review'"), "after the switch, a decision below ReviewBelow goes to review whatever its action")
}

/// Seed runs on every install and upgrade: it adds the sample contacts that are missing and keeps the owner's own.
Method TestSeedKeepsContacts()
{
    Set own = "own"_$Job_"@unit-test.example"
    Do $$$AssertStatusOK(##class(Triage.Data.Contact).Add(own, "client", "unit test"), "a contact of the owner's own")
    Do $$$AssertStatusOK(##class(Triage.Setup).Seed(), "seeded again, as an upgrade does")
    Do $$$AssertEquals(..Contacts(own), 1, "the owner's contact is kept")
    Do $$$AssertEquals(..Contacts("editor@devpress.example"), 1, "a sample contact is there once")
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM Triage_Data.Contact WHERE Address = ?", own)
}

ClassMethod Contacts(address As %String) As %Integer
{
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM Triage_Data.Contact WHERE Address = ?", address)
    Return $Select(rs.%Next(): rs.N, 1: 0)
}

}
