# AL Development Guidelines (Microsoft Official)

Dit bestand bevat de officiële Microsoft AL-richtlijnen en bewezen patronen. Skills in deze plugin lezen dit bestand als referentie.

Bronnen:
- [Microsoft AL Best Practices](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/compliance/apptest-bestpracticesforalcode)
- [AL Guidelines (alguidelines.dev)](https://alguidelines.dev/docs/)
- [Performance for developers](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/performance/performance-developer)

---

## Naamgeving

### Variabelen

- **PascalCase**, altijd — geen underscores, geen speciale tekens
- Variabelenaam **bevat de objectnaam**: `SalesHeader: Record "Sales Header"` (niet `Rec` of `Header`)
- Temporary records: verplicht **`Temp` prefix**: `TempCustomer: Record Customer temporary`
- Geen Hongaarse notatie — geen `l`/`g`/`p` scope-prefixes, geen type-afkortingen
- Labels met foutmeldingen: `Err` suffix (`OrderNotFoundErr: Label 'Order %1 not found.'`)
- Labels met vragen: `Qst` suffix (`ConfirmDeleteQst: Label 'Delete %1?'`)
- Tekst-constanten: `Tok` suffix (`ApiEndpointTok: Label '/api/v2.0', Locked = true`)
- `Locked = true` op labels die niet vertaald mogen worden (URLs, API-paden, codes)

### Procedures

- **PascalCase**, beschrijvende actienaam: `PostSalesOrder()`, `ValidateCustomer()`
- `local` keyword voor private procedures
- Altijd haakjes, ook zonder parameters: `Init()`, `Insert(true)`
- Try-functies: `[TryFunction]` attribuut, naam begint met `Try`: `TryPostDocument()`

### Bestanden

- Formaat: `ObjectName.ObjectType.al`
- Voorbeelden: `SalesOrderMgt.Codeunit.al`, `CustomerCard.Page.al`, `SalesHeader.Table.al`
- Implementatie-codeunits: `Impl` suffix: `SalesPostImpl.Codeunit.al`

### Objecten

- PascalCase met spaties: `"Sales Order Management"`, `"Customer Card"`
- Prefix met feature/groepsnaam voor extensies: `"MYAPP Sales Setup"`
- Verwijs naar objecten op naam, niet op ID

---

## Code-structuur

### Volgorde in AL-objecten

1. Properties
2. Object-constructen (fields, actions, dataset items, etc.)
3. Global variables — Labels eerst, dan overige
4. Triggers
5. Procedures — publiek eerst, dan local

### Algemeen

- Keywords lowercase: `begin`, `end`, `if`, `then`, `else`, `var`, `procedure`
- Built-in methods PascalCase: `FindSet()`, `Modify()`, `SetRange()`
- Business logic hoort in **codeunits**, niet in page/table triggers
- Blank regel tussen procedure-declaraties
- 4 spaties indentatie (geen tabs)

---

## Record-operaties

### SetLoadFields (performance-kritisch)

```al
Customer.SetLoadFields("No.", Name, "Balance (LCY)");
if Customer.FindSet() then
    repeat
        // alleen No., Name, Balance geladen
    until Customer.Next() = 0;
```

- **Verplicht** vóór elke `Get`/`FindFirst`/`FindSet` als je niet alle velden nodig hebt
- Filtervelden worden automatisch meegeladen
- Reset bij `Modify`/`Insert`/`Validate` — daarna opnieuw instellen

### SetRange vs SetFilter

- `SetRange` voor gelijkheid en bereik — sneller, type-safe:
  ```al
  SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
  SalesHeader.SetRange("Posting Date", 20240101D, 20241231D);
  ```
- `SetFilter` alleen voor wildcards, OR, complexe expressies:
  ```al
  Customer.SetFilter(Name, '@*smith*');
  Customer.SetFilter("Balance (LCY)", '>%1|<%2', 1000, -500);
  ```

### Find-patronen

| Patroon | Gebruik | SQL |
|---------|---------|-----|
| `IsEmpty` | Bestaans-check, geen data nodig | `SELECT EXISTS(...)` |
| `FindFirst` | Eén record ophalen | `SELECT TOP 1` |
| `FindSet` | Loop over meerdere records | `SELECT` met cursor |
| `FindSet()` + `LockTable` | Loop + records wijzigen | `SELECT` met update lock |

**Anti-patroon:** `if not IsEmpty then if FindSet then` — 36% trager dan gewoon `FindSet`. IsEmpty is alleen nuttig als je de data zelf niet nodig hebt.

**Deprecated:** `FindSet(true)` en `FindSet(true, true)` zijn deprecated sinds BC v22 (runtime 11.0). Gebruik in plaats daarvan `LockTable()` of `ReadIsolation := IsolationLevel::UpdLock` vóór `FindSet()`:
```al
SalesLine.LockTable();
if SalesLine.FindSet() then
    repeat
        SalesLine.Quantity += 1;
        SalesLine.Modify();
    until SalesLine.Next() = 0;
```

### Get

```al
Customer.SetLoadFields("No.", Name, "Balance (LCY)");
if Customer.Get(CustomerNo) then
    // record gevonden
else
    Error(CustomerNotFoundErr, CustomerNo);
```

- `Get` haalt op primary key, geen filters nodig
- Gebruik `GetBySystemId(SystemId)` voor API-integraties

---

## Foutafhandeling

### Patronen

```al
// TestField — gooit fout als veld leeg of niet gelijk
SalesHeader.TestField("Sell-to Customer No.");
SalesHeader.TestField(Status, SalesHeader.Status::Open);

// FieldError — veldspecifieke fout met context
if Amount < 0 then
    SalesLine.FieldError(Amount, 'must be positive');

// Error — algemene fout, altijd rollback
Error(OrderNotFoundErr, OrderNo);

// TryFunction — vangt exceptions
[TryFunction]
local procedure TryPostDocument(var SalesHeader: Record "Sales Header")
begin
    // code die kan falen
end;

// Aanroep:
if not TryPostDocument(SalesHeader) then
    ErrorMessage := GetLastErrorText();
```

### Collectible Errors (BC19+)

```al
// Fouten verzamelen zonder direct te stoppen
ErrorInfo := ErrorInfo.Create('Validation failed for line ' + Format(LineNo));
ErrorInfo.Collectible := true;
Error(ErrorInfo);

// Later checken
if HasCollectedErrors() then
    Error(''); // toon alle verzamelde fouten
```

### Commit

- **Vermijd** in library-codeunits en event subscribers
- Commit is onomkeerbaar — latere fouten rollen het niet terug
- Gebruik `SuppressCommit` parameter in posting-codeunits
- Nooit in `OnValidate` triggers

---

## Events

### Event-typen

| Type | Contract | Bereik |
|------|----------|--------|
| `[BusinessEvent(true)]` | Formeel — nooit signature wijzigen | Alle apps |
| `[IntegrationEvent(false, false)]` | Informeel — implementatiedetails OK | Alle apps |
| `[InternalEvent(false)]` | Intern — alleen eigen app | Zelfde app |

### Subscriber-patroon

```al
[EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforePostSalesDoc', '', false, false)]
local procedure HandleOnBeforePostSalesDoc(var SalesHeader: Record "Sales Header")
begin
    // subscriber logic
end;
```

- Subscriber-codeunits klein houden (één verantwoordelijkheid)
- Geen `Commit` in subscribers
- Table events (`OnBeforeInsert`, etc.) dwingen row-by-row af bij `ModifyAll`/`DeleteAll` — vermijd in hot paths

### Database trigger events

- `OnBeforeInsert` / `OnAfterInsert`
- `OnBeforeModify` / `OnAfterModify`
- `OnBeforeDelete` / `OnAfterDelete`
- `OnBeforeRename` / `OnAfterRename`
- `OnBeforeValidate` / `OnAfterValidate` (per veld)

---

## Performance

### Data-structuren

- `TextBuilder` voor 5+ string-concatenaties (niet `+=` op Text)
- `Dictionary of [Text, Text]` voor key-value lookups
- `List of [Integer]` voor dynamische arrays
- `Media`/`MediaSet` voor afbeeldingen (niet `Blob`)

### Locking

- `LockTable` zo **laat** mogelijk aanroepen — niet aan begin van procedure
- `ReadIsolation` instellen op record-niveau
- `NumberSequence` voor niet-blokkerende nummering

### Async-patronen

| Methode | Gebruik |
|---------|---------|
| Page Background Tasks | Read-only, UI-gebonden |
| `StartSession` | Onmiddellijk, fire-and-forget |
| `TaskScheduler.CreateTask` | Overleeft herstart |
| Job Queue | Gepland, met logging |

### FlowFields / SIFT

- Voeg `SumIndexFields` key toe voor elk FlowField van type Sum/Count
- Overweeg NCCI (ColumnStoreIndex) voor analytics
- `CalcFields` alleen aanroepen als je de waarde echt nodig hebt

### Web services

- API pages zijn 10x sneller dan SOAP
- `DataAccessIntent = ReadOnly` op queries en read-only API pages
- Retry met backoff bij 429/503/504

---

## Obsolete-lifecycle

```al
field(50100; "Old Field"; Text[100])
{
    ObsoleteState = Pending;
    ObsoleteReason = 'Replaced by "New Field". Use upgrade codeunit to migrate data.';
    ObsoleteTag = '25.0';
}
```

Drie versies: symbol → `Pending` → `Removed`

`Removed` verwijdert het DB-schema **niet** — een upgrade-codeunit moet data kopiëren.

### AppSourceCop regels

- AS0001: tabel verwijderen verboden
- AS0002: veld verwijderen verboden
- AS0005: veld hernoemen verboden
- AS0080: veldlengte verkleinen verboden
- AS0088: verwijderen zonder eerst Pending verboden

---

## Upgrade-codeunits

```al
codeunit 50101 "My Upgrade"
{
    Subtype = Upgrade;

    trigger OnUpgradePerCompany()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if UpgradeTag.HasUpgradeTag(GetMigrateFieldTag()) then
            exit;

        MigrateOldFieldToNewField();
        UpgradeTag.SetUpgradeTag(GetMigrateFieldTag());
    end;

    local procedure GetMigrateFieldTag(): Code[250]
    begin
        exit('MYAPP-50100-MigrateOldField-20240315');
    end;
}
```

- Altijd **UpgradeTag-patroon** gebruiken (niet versiechecks)
- `DataTransfer` voor bulk migratie (>300K rijen)
- `Session.GetExecutionContext()` om externe calls te skippen tijdens upgrade
- Tag-conventie: `[PREFIX]-[ID]-[Beschrijving]-[YYYYMMDD]`

---

## Permission Sets

```al
permissionset 50100 "MyApp - Full"
{
    Assignable = true;
    Caption = 'MyApp Full Access';
    Permissions =
        tabledata "My Table" = RIMD,
        tabledata "My Setup" = RI,
        codeunit "My Management" = X,
        page "My Card" = X;
}
```

- `R`=Read, `I`=Insert, `M`=Modify, `D`=Delete, `X`=Execute
- Assignable name: max 20 tekens
- Extensions op permission sets zijn alleen additief
- `IncludedPermissionSets` voor compositie

---

## DataClassification

Elk tabel-veld **moet** een classificatie hebben (niet `ToBeClassified`):

| Waarde | Gebruik |
|--------|---------|
| `CustomerContent` | Klantdata (namen, adressen, bedragen) |
| `EndUserIdentifiable` | PII (e-mail, telefoon) |
| `SystemMetadata` | Systeemvelden (timestamps, IDs) |
| `AccountData` | Accountgegevens |
| `OrganizationIdentifiable` | Bedrijfsidentificatie |

---

## Object ID ranges

| Bereik | Gebruik |
|--------|---------|
| 0–49.999 | Microsoft base — verboden |
| **50.000–99.999** | Per-tenant extensions (PTE) |
| 100.000–999.999 | Microsoft lokalisaties — verboden |
| 1.000.000–69.999.999 | ISV AppSource (legacy) |
| **70.000.000–74.999.999** | AppSource apps (aanbevolen nieuw) |

Definieer in `app.json` → `"idRanges": [{"from": 50000, "to": 59999}]`

---

## Vertalingen (XLF)

### Activeren

In `app.json`: `"features": ["TranslationFile"]`

Build genereert `Translations/<AppName>.g.xlf` (source only).

### Taalbestanden

Kopieer `.g.xlf` naar `<AppName>.<lang>.xlf` en voeg `<target>` elementen toe:

```xml
<trans-unit id="Table 123 - Field 456 - Property 2879900210" translate="yes">
  <source>Customer Name</source>
  <target state="translated">Klantnaam</target>
  <note from="Xliff Generator" priority="3">Table MyTable - Field CustomerName - Property Caption</note>
</trans-unit>
```

### States

- `needs-translation` — target nog niet vertaald
- `translated` — vertaling aanwezig
- `final` — goedgekeurd

### Regels

- Eén XLF-bestand per taal
- `Locked = true` op labels → wordt NIET opgenomen in XLF
- Bij elke nieuwe Caption/ToolTip/Label: trans-unit toevoegen aan ALLE taalbestanden

---

## Test Framework

### Test-codeunit structuur

```al
codeunit 50150 "My Feature Tests"
{
    Subtype = Test;

    [Test]
    [HandlerFunctions('ConfirmHandler')]
    procedure PostSalesOrderCreatesLedgerEntry()
    var
        SalesHeader: Record "Sales Header";
        GLEntry: Record "G/L Entry";
    begin
        // GIVEN
        CreateSalesOrder(SalesHeader);

        // WHEN
        LibrarySales.PostSalesDocument(SalesHeader, true, true);

        // THEN
        GLEntry.SetRange("Document No.", SalesHeader."No.");
        Assert.RecordIsNotEmpty(GLEntry);
    end;

    [ConfirmHandler]
    procedure ConfirmHandler(Question: Text[1024]; var Reply: Boolean)
    begin
        Reply := true;
    end;
}
```

### Handler-attributen

- `[MessageHandler]` — vangt Message() op
- `[ConfirmHandler]` — vangt Confirm() op
- `[StrMenuHandler]` — vangt StrMenu() op
- `[PageHandler]` / `[ModalPageHandler]` — vangt Page.Run/RunModal op
- `[ReportHandler]` — vangt Report.Run op
- `[SendNotificationHandler]` — vangt Notification.Send op

### Best practices

- GIVEN/WHEN/THEN patroon
- Eén assertie-concept per test
- Library-codeunits voor testdata-setup (bijv. `Library - Sales`)
- `TestPermissions` property voor rechten-tests

---

## API Pages

```al
page 50100 "My API Page"
{
    PageType = API;
    APIPublisher = 'mycompany';
    APIGroup = 'myapp';
    APIVersion = 'v1.0';
    EntityName = 'customer';
    EntitySetName = 'customers';
    SourceTable = Customer;
    DelayedInsert = true;
    ODataKeyFields = SystemId;
    DataAccessIntent = ReadOnly;

    layout
    {
        area(Content)
        {
            field(id; Rec.SystemId) { }
            field(number; Rec."No.") { }
            field(displayName; Rec.Name) { }
        }
    }
}
```

- camelCase voor `EntityName`, `EntitySetName`, `APIPublisher`, `APIGroup`
- `DelayedInsert = true` verplicht
- `ODataKeyFields = SystemId` aanbevolen
- API pages zijn niet uitbreidbaar (geen page extensions)
