Include %occInclude

/// Triage.Export, the Java operation (PEX): its classes are built at install, and a decision becomes one JSON line.
Class Triage.Test.Export Extends %UnitTest.TestCase
{

Method TestBuiltAndConfigured()
{
    Do $$$AssertTrue(##class(%File).Exists(##class(Triage.Setup).DataDir()_"classes/triage/ExportOperation.class"), "javac built the operation at install")
    Do $$$AssertStatusOK(##class(Triage.Setup).Configure(), "configuration applied")
    Set row = ##class(Ens.Config.DefaultSettings).%OpenId("Triage.Production||Triage.Export||EnsLib.PEX.BusinessOperation||%gatewayExtraClasspaths")
    Do $$$AssertTrue($IsObject(row) && (row.SettingValue [ "intersystems-pex-") && (row.SettingValue [ "|"), "the PEX library and the classes are on the item's classpath")
}

Method TestDecisionAsJsonLine()
{
    Set d = ##class(Triage.Msg.Decision).%New()
    Set d.DecisionId = 42, d.MessageId = "<x1@unit-test.example>", d.Sender = "jpark@northbay.example", d.Subject = "Re: ""our"" call"
    Set d.Category = "other", d.Urgency = "normal", d.Action = "review", d.Confidence = 0.45
    Set d.Reason = "Unknown sender."_$Char(10)_"Asks for bank details.", d.Body = "Please send the signed document."
    Set gw = $System.external.getJavaGateway()
    Do gw.addToPath(##class(Triage.Setup).Jar("intersystems-pex-"))
    Do gw.addToPath(##class(Triage.Setup).DataDir()_"classes")
    Set line = gw.invoke("triage.ExportOperation", "toJson", d)
    Do $$$AssertTrue(line '[ $Char(10), "one line: the newline in the reason is escaped")
    Set json = {}.%FromJSON(line)
    Do $$$AssertEquals(json.decisionId, 42, "decision id")
    Do $$$AssertEquals(json.subject, "Re: ""our"" call", "quotes survive the round trip")
    Do $$$AssertEquals(json.reason, d.Reason, "the reason, newline included")
    Do $$$AssertEquals(json.action, "review", "action")
    Do $$$AssertEquals(json.confidence, .45, "confidence as a number")
    Do $$$AssertTrue(json.exportedAt '= "", "time of the export")
    Do $$$AssertEquals(json.%IsDefined("body"), 0, "the email body stays in IRIS")
}

}
