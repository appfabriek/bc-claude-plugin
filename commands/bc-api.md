---
name: bc-api
description: Generate API page or API query for a BC table
bc-version: ">=20.0"
---

# BC API

Genereer een API page (v2.0) of API query object voor een BC-tabel.

## Input

$ARGUMENTS — tabelnaam en optionele flags:
- "Customer" — API page voor Customer tabel
- "MYAPP Sales Discount" — API page voor custom tabel
- "Customer --query" — API query in plaats van page
- "Sales Header --actions" — inclusief bound actions

## Instructies

### Stap 0 — Laad kennis

1. Lees `knowledge/bc-api-patterns.md` voor API page/query structuur.
2. Lees `knowledge/al-guidelines.md` voor naamgeving.
3. Lees `knowledge/bc-version-matrix.md` → API query vereist BC 22+.
4. Lees `app.json` → `idRanges`, prefix.

### Stap 1 — Analyseer de tabel

Lees de tabel-definitie (AL source of `knowledge/bc-tables.md` voor standaardtabellen):
- Velden: naam, type, lengte
- FlowFields (read-only in API)
- Primary key
- Relaties (TableRelation)

### Stap 2 — Genereer API page

```al
page <ID> "<PREFIX> <EntityName> API"
{
    PageType = API;
    APIPublisher = '<publisher>';    // camelCase uit app.json
    APIGroup = '<appgroup>';          // camelCase uit app naam
    APIVersion = 'v2.0';
    EntityName = '<entityName>';      // camelCase enkelvoud
    EntitySetName = '<entityNames>';  // camelCase meervoud
    SourceTable = "<Table Name>";
    DelayedInsert = true;
    ODataKeyFields = SystemId;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(id; Rec.SystemId)
                {
                    Caption = 'Id';
                    Editable = false;
                }
                // Per tabel-veld:
                field(<camelCaseName>; Rec."<Field Name>")
                {
                    Caption = '<Caption>';
                }
            }
        }
    }
}
```

**Veldnamen in API:**
- camelCase: `displayName`, `balanceLCY`, `postingDate`
- `id` voor SystemId
- `number` voor "No."
- `displayName` voor Name
- FlowFields: `Editable = false`

### Stap 3 — Genereer API query (bij --query)

```al
query <ID> "<PREFIX> <EntityName> Query"
{
    QueryType = API;
    APIPublisher = '<publisher>';
    APIGroup = '<appgroup>';
    APIVersion = 'v2.0';
    EntityName = '<entityName>';
    EntitySetName = '<entityNames>';
    DataAccessIntent = ReadOnly;

    elements
    {
        dataitem(<Table>; "<Table Name>")
        {
            column(<camelCase>; "<Field Name>") { }
        }
    }
}
```

### Stap 4 — Voeg bound actions toe (bij --actions)

```al
    [ServiceEnabled]
    procedure Post(var ActionContext: WebServiceActionContext)
    begin
        // implementatie
        ActionContext.SetResultCode(WebServiceActionResultCode::Updated);
    end;
```

### Stap 5 — Rapporteer

- Toon de gegenereerde API endpoint URL
- Voorbeeld curl-aanroep
- Als relevant: suggereer nested parts voor gerelateerde tabellen

## Regels

- ALTIJD `DelayedInsert = true` op API pages
- ALTIJD `ODataKeyFields = SystemId`
- ALTIJD camelCase voor EntityName, EntitySetName, veldnamen
- FlowFields zijn ALTIJD `Editable = false`
- API pages zijn NIET uitbreidbaar — vermeld dit als de gebruiker een base tabel kiest
- Lees `knowledge/bc-api-patterns.md` voor alle conventies
