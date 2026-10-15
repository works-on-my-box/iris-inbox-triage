/// People and organizations the inbox owner already deals with.
Class Triage.Data.Contact Extends %Persistent
{

Property Address As %String(MAXLEN = 320);

/// Lower-case domain of the address, for domain-level lookups.
Property MailDomain As %String(MAXLEN = 200);

/// client, editor, platform, vendor, personal
Property Kind As %String(MAXLEN = 40);

Property Note As %String(MAXLEN = 500);

Index AddressIdx On Address;

Index MailDomainIdx On MailDomain;

ClassMethod Add(address As %String, kind As %String, note As %String = "") As %Status
{
    Set c = ..%New()
    Set c.Address = $ZConvert(address, "L")
    Set c.MailDomain = $ZConvert($Piece(address, "@", 2), "L")
    Set c.Kind = kind
    Set c.Note = note
    Return c.%Save()
}

}
