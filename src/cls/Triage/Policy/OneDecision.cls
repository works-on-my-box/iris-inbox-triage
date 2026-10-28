Include %AI

/// Authorization policy: RecordDecision may run once per email. The agent is told to call it exactly once;
/// this makes the rule hold even when the model does not follow its instructions.
Class Triage.Policy.OneDecision Extends (%AI.Policy.Authorization, %XML.Adaptor)
{

Parameter XMLNAME = "Authorization";

Method %CanExecute(toolref As %String, call As %DynamicObject, metadata As %DynamicObject) As %Status
{
    If (call.name = "RecordDecision") && $Data(^||Triage.Decision) {
        Return $$$ERROR($$$AICoreToolAccessDenied, "The decision for this email is already recorded")
    }
    Return $$$OK
}

}
