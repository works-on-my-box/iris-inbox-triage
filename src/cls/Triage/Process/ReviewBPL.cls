Include %occInclude

/// The review queue on the Workflow Engine: an email the agent was unsure about becomes a task for the
/// "Triage Reviewers" role. The reviewer opens it in the Workflow Inbox, reads the agent's verdict and the email,
/// and picks Alert, Draft or Archive; the choice is recorded on the decision and routed like an agent decision.
Class Triage.Process.ReviewBPL Extends Ens.BusinessProcessBPL
{

XData BPL [ XMLNamespace = "http://www.intersystems.com/bpl" ]
{
<process language='objectscript' request='Triage.Msg.Decision' response='Ens.Response' height='2000' width='2000' >
<context>
<property name='Choice' type='%String' instantiate='0' />
<property name='Reviewer' type='%String' instantiate='0' />
<property name='Routed' type='Triage.Msg.Decision' instantiate='0' />
</context>
<sequence xend='200' yend='950' >
<code name='Open for review' xpos='200' ypos='250' >
<annotation>The decision is marked review while the task is open.</annotation>
<![CDATA[ Set status = ##class(Triage.Process.ReviewBPL).MarkOpen(request.DecisionId) ]]>
</code>
<call name='Ask a person' target='Triage Reviewers' async='1' xpos='200' ypos='350' >
<annotation>A Workflow task for the Triage Reviewers role, shown in the Workflow Inbox of every member.</annotation>
<request type='EnsLib.Workflow.TaskRequest' >
<assign property="callrequest.%Subject" value='$Extract("Triage review: "_request.Subject, 1, 255)' action="set" />
<assign property="callrequest.%Message" value='##class(Triage.Process.ReviewBPL).TaskText(request)' action="set" />
<assign property="callrequest.%Actions" value='"Alert,Draft,Archive"' action="set" />
<assign property="callrequest.%Priority" value='$Case(request.Urgency, "hot": 1, "normal": 3, : 5)' action="set" />
</request>
<response type='EnsLib.Workflow.TaskResponse' >
<assign property="context.Choice" value="callresponse.%Action" action="set" />
<assign property="context.Reviewer" value="callresponse.%UserName" action="set" />
</response>
</call>
<sync name='Wait for the reviewer' calls='Ask a person' type='all' xpos='200' ypos='450' />
<code name='Record the review' xpos='200' ypos='550' >
<annotation>The person's action replaces the agent's for routing; the decision row keeps both.</annotation>
<![CDATA[ Set context.Routed = ##class(Triage.Process.ReviewBPL).Reviewed(request, context.Choice, context.Reviewer) ]]>
</code>
<switch name='Reviewer chose' xpos='200' ypos='650' xend='200' yend='850' >
<case condition='$IsObject(context.Routed) &amp;&amp; (context.Routed.Action="alert")' >
<call name='Alert' target='Triage.Alert' async='1' xpos='-70' ypos='750' >
<request type='Triage.Msg.Decision' >
<assign property="callrequest" value="context.Routed" action="set" />
</request>
</call>
</case>
<case condition='$IsObject(context.Routed) &amp;&amp; (context.Routed.Action="draft_reply")' >
<call name='Draft a reply' target='Triage.Draft' async='1' xpos='200' ypos='750' >
<request type='Triage.Msg.Decision' >
<assign property="callrequest" value="context.Routed" action="set" />
</request>
</call>
</case>
<case condition='$IsObject(context.Routed) &amp;&amp; (context.Routed.Action="archive")' >
<call name='Archive' target='Triage.Archive' async='1' xpos='470' ypos='750' >
<request type='Triage.Msg.Decision' >
<assign property="callrequest" value="context.Routed" action="set" />
</request>
</call>
</case>
<default/>
</switch>
</sequence>
</process>
}

ClassMethod MarkOpen(decisionId As %Integer) As %Status
{
    Set row = ##class(Triage.Data.Decision).%OpenId(decisionId)
    If '$IsObject(row) Return $$$ERROR($$$GeneralError, "No decision "_decisionId)
    Set row.Status = "review"
    Return row.%Save()
}

/// What the reviewer reads in the Workflow Inbox (the task message holds up to 2,000 characters):
/// who wrote, what the agent decided and why, then as much of the email as fits.
ClassMethod TaskText(d As Triage.Msg.Decision) As %String
{
    Set from = $Select(d.SenderName = "": d.Sender, 1: d.SenderName_" <"_d.Sender_">")
    Set head = "From: "_from_$Char(10)_"Subject: "_d.Subject_$Char(10)
    Set head = head_"Agent: "_d.Category_" / "_d.Urgency_" / "_d.Action_", confidence "_d.Confidence_$Char(10)
    Set head = $Extract(head_"Reason: "_d.Reason, 1, 1500)_$Char(10, 10)
    Return head_$Extract(d.Body, 1, 2000 - $Length(head))
}

/// The open review tasks in a user's Workflow Inbox; with an action (Alert, Draft or Archive) each one is completed
/// the way the inbox does it: take ownership, then the action. For scripts/review.sh. Returns the number completed.
ClassMethod CompleteOpen(action As %String = "", user As %String = "_SYSTEM") As %Integer
{
    Set done = 0
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT w.ID, t.%Subject AS Subject FROM EnsLib_Workflow.Worklist w, EnsLib_Workflow.TaskResponse t WHERE t.ID = w.Task AND w.UserName = ? AND w.RoleName = 'Triage Reviewers' ORDER BY w.TimeCreated", user)
    While rs.%Next() {
        Write rs.ID, "  ", rs.Subject, !
        Continue:action=""
        $$$ThrowOnError(##class(EnsLib.Workflow.Engine).%TakeOwnershipForTask(rs.ID, user, .msg))
        $$$ThrowOnError(##class(EnsLib.Workflow.Engine).%ProcessAction(action, rs.ID, user, .msg))
        If msg '= "" Write "  ", msg, !
        Set done = done + 1
    }
    Return done
}

/// Records the reviewer's choice on the decision row and returns a copy of the decision with the person's action,
/// or "" when the task closed without one of the three actions (then nothing is routed and the decision stays in review).
ClassMethod Reviewed(d As Triage.Msg.Decision, choice As %String, user As %String) As Triage.Msg.Decision
{
    Set action = $Case($ZConvert(choice, "L"), "alert": "alert", "draft": "draft_reply", "archive": "archive", : "")
    If action = "" Return ""
    Set row = ##class(Triage.Data.Decision).%OpenId(d.DecisionId)
    If $IsObject(row) {
        Set row.ReviewedBy = user, row.ReviewAction = action, row.ReviewedAt = $ZDateTime($Horolog, 3), row.Status = "reviewed"
        $$$ThrowOnError(row.%Save())
    }
    Set routed = d.%ConstructClone()
    Set routed.Action = action
    Return routed
}

}
