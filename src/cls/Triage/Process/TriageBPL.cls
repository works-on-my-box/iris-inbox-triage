/// The triage workflow drawn in BPL: the same steps as Triage.Process.Triage, visible as a diagram in the
/// Management Portal (Interoperability > Build > Business Processes). Triage.Inbox.Mail targets this process.
Class Triage.Process.TriageBPL Extends Ens.BusinessProcessBPL
{

/// Decisions below this confidence also go to a person.
Property ReviewBelow As %Numeric [ InitialExpression = 0.6 ];

Parameter SETTINGS = "ReviewBelow:Triage";

XData BPL [ XMLNamespace = "http://www.intersystems.com/bpl" ]
{
<process language='objectscript' request='Triage.Msg.Email' response='Ens.Response' height='2000' width='2000' >
<context>
<property name='Verdict' type='Triage.Msg.Verdict' instantiate='0' />
<property name='Decision' type='Triage.Msg.Decision' instantiate='0' />
</context>
<sequence xend='200' yend='1300' >
<scope xpos='200' ypos='250' xend='200' yend='450' >
<annotation>If the agent operation fails even after its retries, the email still reaches a person: the fault handler records a fallback verdict.</annotation>
<call name='Ask the agent' target='Triage.Agent' async='0' timeout='300' xpos='200' ypos='250' >
<annotation>The agent operation looks the sender up, reads the history and records one decision.</annotation>
<request type='Triage.Msg.Email' >
<assign property="callrequest" value="request" action="set" />
</request>
<response type='Triage.Msg.Verdict' >
<assign property="context.Verdict" value="callresponse" action="set" />
</response>
</call>
<faulthandlers>
<catchall xpos='200' ypos='350' xend='200' yend='550' >
<trace value='"No verdict from the agent: "_$System.Status.GetErrorText(context.%LastError)' xpos='200' ypos='250' />
<assign property="context.Verdict" value='##class(Triage.Msg.Verdict).Fallback("The agent did not answer, so a person should look at this email.")' action="set" xpos='200' ypos='350' />
</catchall>
</faulthandlers>
</scope>
<code name='Record the decision' xpos='200' ypos='550' >
<annotation>Fallback to review when the agent did not answer; one row in Triage_Data.Decision per email.</annotation>
<![CDATA[
 If '$IsObject(context.Verdict) Set context.Verdict = ##class(Triage.Msg.Verdict).Fallback("The agent did not answer, so a person should look at this email.")
 Set row = ##class(Triage.Data.Decision).Record(request, context.Verdict)
 Set context.Decision = ##class(Triage.Msg.Decision).FromRow(row, request)
]]>
</code>
<if name='Urgent?' condition='(context.Decision.Urgency="hot") || (context.Decision.Action="alert")' xpos='200' ypos='650' xend='200' yend='850' >
<true>
<call name='Alert' target='Triage.Alert' async='1' xpos='335' ypos='750' >
<request type='Triage.Msg.Decision' >
<assign property="callrequest" value="context.Decision" action="set" />
</request>
</call>
</true>
</if>
<switch name='Action' xpos='200' ypos='950' xend='200' yend='1150' >
<case condition='context.Decision.Action="draft_reply"' >
<call name='Draft a reply' target='Triage.Draft' async='1' xpos='470' ypos='1050' >
<request type='Triage.Msg.Decision' >
<assign property="callrequest" value="context.Decision" action="set" />
</request>
</call>
</case>
<case condition='context.Decision.Action="archive"' >
<call name='Archive' target='Triage.Archive' async='1' xpos='200' ypos='1050' >
<request type='Triage.Msg.Decision' >
<assign property="callrequest" value="context.Decision" action="set" />
</request>
</call>
</case>
<case condition='(context.Decision.Action="review") || (context.Decision.Confidence &lt; process.ReviewBelow)' >
<call name='Review' target='Triage.Review' async='1' xpos='-70' ypos='1050' >
<request type='Triage.Msg.Decision' >
<assign property="callrequest" value="context.Decision" action="set" />
</request>
</call>
</case>
<default/>
</switch>
</sequence>
</process>
}

}
