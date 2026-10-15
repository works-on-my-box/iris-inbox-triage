/// Tools the triage agent may call. Lookups are read-only SQL; RecordDecision is how the agent answers.
Class Triage.Agent.Tools Extends %AI.ToolSet [ DependsOn = (Triage.Data.Contact, Triage.Data.Decision) ]
{

Parameter CATEGORIES = "client,editorial,platform,billing,newsletter,spam,personal,other";

Parameter URGENCIES = "hot,normal,low";

Parameter ACTIONS = "alert,review,draft_reply,archive";

XData Definition [ MimeType = application/xml ]
{
<ToolSet Name="TriageTools">
  <Query Name="LookupContact"
         Description="Find the sender in the known contacts by exact address or by domain. Returns kind (client, editor, platform, vendor, personal) and a note."
         Arguments="address As %String, domain As %String"
         MaxRows="5">
    <![CDATA[
      SELECT Address, Kind, Note
      FROM Triage_Data.Contact
      WHERE Address = LOWER(:address) OR MailDomain = LOWER(:domain)
    ]]>
  </Query>
  <Query Name="SenderHistory"
         Description="Earlier triage decisions for mail from this domain, newest first."
         Arguments="domain As %String"
         MaxRows="5">
    <![CDATA[
      SELECT Subject, Category, Urgency, Action, DecidedAt
      FROM Triage_Data.Decision
      WHERE SenderDomain = LOWER(:domain)
      ORDER BY DecidedAt DESC
    ]]>
  </Query>
  <Tool Name="RecordDecision" Method="RecordDecision"/>
</ToolSet>
}

/// Record the triage decision for the current email. Call it exactly once, after the lookups.
ClassMethod RecordDecision(category As %String(DESCRIPTION = "One of: client, editorial, platform, billing, newsletter, spam, personal, other"), urgency As %String(DESCRIPTION = "One of: hot, normal, low"), action As %String(DESCRIPTION = "One of: alert, review, draft_reply, archive"), reason As %String(DESCRIPTION = "One or two sentences that cite the facts used"), confidence As %Float(DESCRIPTION = "0 to 1: how sure you are")) As %String
{
    Set category = $ZConvert($ZStrip(category, "<>W"), "L")
    Set urgency = $ZConvert($ZStrip(urgency, "<>W"), "L")
    Set action = $ZConvert($ZStrip(action, "<>W"), "L")
    If '..Allowed(category, ..#CATEGORIES) Return "Not recorded: category must be one of "_..#CATEGORIES
    If '..Allowed(urgency, ..#URGENCIES) Return "Not recorded: urgency must be one of "_..#URGENCIES
    If '..Allowed(action, ..#ACTIONS) Return "Not recorded: action must be one of "_..#ACTIONS
    Set confidence = $Select(confidence < 0: 0, confidence > 1: 1, 1: +confidence)
    // Tools run in the caller's process, so the business process reads the decision back from here.
    Set ^||Triage.Decision = $ListBuild(category, urgency, action, $Extract(reason, 1, 1000), confidence)
    Return "Recorded."
}

ClassMethod Allowed(value As %String, list As %String) As %Boolean
{
    Return value '= "" && ($ListFind($ListFromString(list), value) > 0)
}

}
