---
name: bc-new
description: Scaffold a new AL object (table, page, codeunit, report, etc.)
bc-version: ">=14.0"
---

# BC New Object

Scaffold een nieuw AL-object met de juiste naamgeving, ID, en structuur.

## Input

$ARGUMENTS — object type en optionele naam, bijvoorbeeld:
- "table Sales Discount"
- "page Customer Discount List"
- "codeunit Sales Discount Mgt"
- "enum Document Status"
- "permissionset"

## Instructies

### Stap 0 — Lees projectcontext

1. Lees `app.json` → `name`, `idRanges`, `mandatoryAffixes` (indien aanwezig).
2. Lees `knowledge/al-guidelines.md` voor naamgevingsregels.
3. Lees `knowledge/bc-version-matrix.md` voor feature-beschikbaarheid.
4. Scan bestaande AL-bestanden om het volgende te detecteren:
   - Mapstructuur (bijv. `src/Tables/`, `src/Pages/` of platte structuur)
   - Hoogst gebruikte object ID per type
   - Prefix-conventie (bijv. `MYAPP` of projectnaam)

### Stap 1 — Bepaal object type

Ondersteunde types en hun ID-bereiken:

| Type | AL keyword | Bestandsformat |
|------|-----------|----------------|
| table | `table` | `ObjectName.Table.al` |
| tableextension | `tableextension` | `ObjectName.TableExt.al` |
| page | `page` | `ObjectName.Page.al` |
| pageextension | `pageextension` | `ObjectName.PageExt.al` |
| codeunit | `codeunit` | `ObjectName.Codeunit.al` |
| report | `report` | `ObjectName.Report.al` |
| reportextension | `reportextension` | `ObjectName.ReportExt.al` |
| query | `query` | `ObjectName.Query.al` |
| xmlport | `xmlport` | `ObjectName.Xmlport.al` |
| enum | `enum` | `ObjectName.Enum.al` |
| enumextension | `enumextension` | `ObjectName.EnumExt.al` |
| interface | `interface` | `ObjectName.Interface.al` |
| permissionset | `permissionset` | `ObjectName.PermissionSet.al` |
| profile | `profile` | `ObjectName.Profile.al` |

### Stap 2 — Bepaal ID en naam

1. **ID:** Kies het volgende vrije ID binnen `idRanges` uit `app.json`. Scan bestaande objecten van hetzelfde type en neem het maximum + 1.
2. **Naam:** Gebruik de opgegeven naam, voorafgegaan door het app-prefix als `mandatoryAffixes` is ingesteld. PascalCase met spaties.
3. **Bestandsnaam:** `ObjectName.ObjectType.al` — zonder prefix als dat dubbelop is.

### Stap 3 — Genereer het object

Gebruik het juiste template per type. Hieronder de meest gebruikte:

#### Table

```al
table <ID> "<PREFIX> <Name>"
{
    Caption = '<Name>';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[20])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }
}
```

#### Page (Card)

```al
page <ID> "<PREFIX> <Name> Card"
{
    PageType = Card;
    Caption = '<Name>';
    SourceTable = "<PREFIX> <Table Name>";
    ApplicationArea = All;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                // fields
            }
        }
    }
}
```

#### Page (List)

```al
page <ID> "<PREFIX> <Name> List"
{
    PageType = List;
    Caption = '<Name> List';
    SourceTable = "<PREFIX> <Table Name>";
    ApplicationArea = All;
    UsageCategory = Lists;
    CardPageId = "<PREFIX> <Name> Card";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                // fields
            }
        }
    }
}
```

#### Codeunit

```al
codeunit <ID> "<PREFIX> <Name>"
{
    Access = Internal;

    procedure DoSomething()
    begin
        // TODO: implement
    end;
}
```

#### Enum

```al
enum <ID> "<PREFIX> <Name>"
{
    Extensible = true;
    Caption = '<Name>';

    value(0; " ")
    {
        Caption = ' ';
    }
    value(1; "Value1")
    {
        Caption = 'Value 1';
    }
}
```

#### PermissionSet

```al
permissionset <ID> "<PREFIX> - <Role>"
{
    Assignable = true;
    Caption = '<App Name> <Role>';

    Permissions =
        // tabledata, page, codeunit entries
        ;
}
```

### Stap 4 — Plaats het bestand

- Detecteer de mapstructuur van het project:
  - Als `src/<Type>s/` mappen bestaan → plaats daar
  - Als `src/<FeatureArea>/` mappen bestaan → vraag in welke area
  - Anders → in de root of `src/`

### Stap 5 — Rapporteer

Toon:
- Object type, ID, naam
- Bestandspad
- Eventuele aanbevelingen (bijv. "vergeet niet een List page aan te maken" bij een nieuwe tabel)

## Regels

- Volg ALTIJD `knowledge/al-guidelines.md` voor naamgeving
- Gebruik ALTIJD het volgende vrije ID uit `idRanges` — raad geen ID
- Voeg ALTIJD `DataClassification` toe op tabelvelden
- Voeg ALTIJD `Caption` toe op elk veld en object
- Bij een nieuwe tabel: stel voor om ook een Card + List page aan te maken
- Bij een nieuw permissionset: gebruik `/bc-permissions --generate` voor volledige set
