/// Writes a draft reply with Triage.Agent.Writer, stores it in Triage_Data.Draft and, when the Owner setting names a mailbox,
/// mails it there through the SMTP adapter so the owner can edit and send it from the mail client.
Class Triage.Operation.Draft Extends Ens.BusinessOperation
{

Parameter ADAPTER = "EnsLib.EMail.OutboundAdapter";

Parameter INVOCATION = "Queue";

Property Adapter As EnsLib.EMail.OutboundAdapter;

/// A %AI.Agent subclass that returns the reply text.
Property AgentClass As %String(MAXLEN = 200) [ InitialExpression = "Triage.Agent.Writer" ];

/// Mailbox that receives the drafts; empty = store them only.
Property Owner As %String(MAXLEN = 320);

Parameter SETTINGS = "AgentClass:Draft,Owner:Draft";

Method OnMessage(pRequest As Triage.Msg.Decision, Output pResponse As Ens.Response) As %Status
{
    Try {
        Set agent = $ClassMethod(..AgentClass, "%New")
        $$$ThrowOnError(agent.%Init())
        Set session = agent.CreateSession({"max_iterations": 1, "temperature": 0.3})
        Set text = agent.Chat(session, ..Prompt(pRequest)).Content
    } Catch ex {
        Set text = ex.DisplayString()
        Set ..Retry = ##class(Triage.Operation.Agent).Transient(text)
        Return $$$ERROR($$$EnsErrGeneral, "Draft writer failed: "_text)
    }
    Set draft = ##class(Triage.Data.Draft).%New()
    Set draft.DecisionId = pRequest.DecisionId
    Set draft.Recipient = pRequest.Sender
    Set draft.Subject = $Select($ZConvert($Extract(pRequest.Subject, 1, 3), "L") = "re:": pRequest.Subject, 1: "Re: "_pRequest.Subject)
    Set draft.Body = text
    If ..Owner '= "" {
        Set mail = ##class(%Net.MailMessage).%New()
        Do mail.To.Insert(..Owner)
        Set mail.Subject = "Draft reply: "_pRequest.Subject
        Do mail.TextData.Write("To: "_pRequest.Sender_$Char(10)_"Subject: "_draft.Subject_$Char(10, 10)_text_$Char(10, 10)_"---- original message ----"_$Char(10)_pRequest.Body)
        Set sc = ..Adapter.SendMail(mail, .failed)
        If $$$ISOK(sc) {
            Set draft.Status = "mailed"
        } Else {
            $$$LOGWARNING("Draft stored but not mailed: "_$System.Status.GetErrorText(sc))
        }
    }
    $$$ThrowOnError(draft.%Save())
    Set row = ##class(Triage.Data.Decision).%OpenId(pRequest.DecisionId)
    If $IsObject(row) Set row.Status = "drafted" $$$ThrowOnError(row.%Save())
    Quit $$$OK
}

/// The contact note, the triage reason and the email itself.
ClassMethod Prompt(d As Triage.Msg.Decision) As %String
{
    Set note = ""
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT Kind, Note FROM Triage_Data.Contact WHERE Address = ?", $ZConvert(d.Sender, "L"))
    If rs.%Next() Set note = "Contact note: "_rs.Kind_"; "_rs.Note_$Char(10)
    Set from = $Select(d.SenderName = "": d.Sender, 1: d.SenderName_" <"_d.Sender_">")
    Return note_"Triage reason: "_d.Reason_$Char(10, 10)_"From: "_from_$Char(10)_"Subject: "_d.Subject_$Char(10, 10)_$Extract(d.Body, 1, 6000)
}

}
