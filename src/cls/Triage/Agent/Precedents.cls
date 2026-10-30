Include %occInclude

/// Earlier emails and how they were decided, as an AI Hub knowledge base on IRIS Vector Search:
/// %AI.RAG.KnowledgeBase over %AI.RAG.VectorStore.IRIS (table Triage_Data.Precedent, 384-dimension vectors from the
/// local FastEmbed model, no API key). The classifier gets it as the search_precedents tool. Every email the agent decides
/// is added; when a person decides it in review, the email is re-indexed with the person's decision, so the next email
/// like it is decided the way the person decided.
Class Triage.Agent.Precedents Extends %RegisteredObject
{

Parameter TABLE = "Triage_Data.Precedent";

Property KB As %AI.RAG.KnowledgeBase;

/// Opens the knowledge base in this process: creates the table on first use and loads the embedding model.
ClassMethod Open() As Triage.Agent.Precedents
{
    Set emb = ##class(%AI.RAG.Embedding.FastEmbed).Create()
    Set store = ##class(%AI.RAG.VectorStore.IRIS).%New()
    Set store.Schema = $Piece(..#TABLE, ".", 1), store.TableName = ..#TABLE
    Set store.Dimensions = 384, store.ModelName = "AllMiniLML6V2"
    $$$ThrowOnError(store.Build())
    Set kb = ##class(%AI.RAG.KnowledgeBase).%New("search_precedents", "Earlier emails like this one and how they were decided. A decision made by a person in review is marked as such and outranks one made by the agent.")
    Set kb.TopK = 3
    $$$ThrowOnError(kb.Build(emb, store))
    Set p = ..%New()
    Set p.KB = kb
    Return p
}

/// The key of an email's precedent: its Message-ID, or sender and subject for a file without one.
ClassMethod Source(messageId As %String, sender As %String, subject As %String) As %String
{
    Return $Select(messageId '= "": messageId, 1: "no-id:"_$ZConvert(sender, "L")_":"_subject)
}

/// The indexed text of one email: the decision first, then who wrote and about what. The knowledge base splits long
/// text into chunks, so the decision leads and the body is cut short: every chunk a search returns starts with it.
ClassMethod Text(sender As %String, subject As %String, body As %String, action As %String, by As %String) As %String
{
    Return "Decided by "_by_": "_action_". Earlier email from "_$Piece(sender, "@", 2)_", subject: "_subject_". "_$Extract($ZStrip($Translate(body, $Char(10), " "), "=W"), 1, 300)
}

/// An email the agent has just decided.
Method AddDecided(email As Triage.Msg.Email, verdict As Triage.Msg.Verdict) As %Status
{
    Set text = ..Text(email.Sender, email.Subject, email.Body, verdict.Action, "the agent")
    Return ..KB.AddDocument(text, {"source": (..Source(email.MessageId, email.Sender, email.Subject)), "category": (verdict.Category), "action": (verdict.Action), "decided_by": "agent"})
}

/// The same email after review: its precedent now carries the person's decision instead of the agent's.
Method Reviewed(decision As Triage.Msg.Decision, reviewer As %String) As %Status
{
    Set text = ..Text(decision.Sender, decision.Subject, decision.Body, decision.Action, "a person in review")
    Set source = ..Source(decision.MessageId, decision.Sender, decision.Subject)
    Set count = ..KB.ReindexDocument(source, text, {"category": (decision.Category), "action": (decision.Action), "decided_by": "person", "reviewer": (reviewer)})
    Return $Select(count > 0: $$$OK, 1: $$$ERROR($$$GeneralError, "Nothing re-indexed for "_source))
}

}
