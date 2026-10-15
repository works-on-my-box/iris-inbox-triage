Include %occInclude

/// Demo data and helpers.
Class Triage.Setup
{

/// Known contacts for the sample emails. All addresses are made up.
ClassMethod Seed() As %Status
{
    Do ##class(Triage.Data.Contact).%KillExtent()
    $$$ThrowOnError(##class(Triage.Data.Contact).Add("editor@devpress.example", "editor", "Runs the paid technical writing program; two pitches sent in October"))
    $$$ThrowOnError(##class(Triage.Data.Contact).Add("billing@cloudhost.example", "platform", "VPS provider that hosts the owner's automation"))
    $$$ThrowOnError(##class(Triage.Data.Contact).Add("maria@shopco.example", "client", "Small online shop; asked for a price scraper in September"))
    $$$ThrowOnError(##class(Triage.Data.Contact).Add("news@weeklydigest.example", "vendor", "Newsletter the owner subscribed to"))
    Return $$$OK
}

}
