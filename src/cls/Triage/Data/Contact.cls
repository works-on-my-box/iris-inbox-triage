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

/// Mail providers whose domain is shared by unrelated people: a contact there is known by its address only.
Parameter SHAREDDOMAINS = "gmail.com,googlemail.com,outlook.com,hotmail.com,live.com,msn.com,yahoo.com,ymail.com,icloud.com,me.com,mac.com,aol.com,proton.me,protonmail.com,gmx.com,gmx.net,gmx.de,mail.com,zoho.com,yandex.ru,yandex.com,mail.ru,qq.com,163.com";

/// 1 for the domain of a shared mail provider (gmail.com and the like), where the domain says nothing about the sender.
ClassMethod Shared(domain As %String) As %Boolean [ SqlProc ]
{
    Return $ListFind($ListFromString(..#SHAREDDOMAINS), $ZConvert(domain, "L")) > 0
}

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
