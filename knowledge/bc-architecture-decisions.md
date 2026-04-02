# BC Architecture Decisions

Senior-level architectuurkennis voor het ontwerpen van goede BC-software.

---

## Object Strategie

### Table Extension vs Nieuwe Tabel

| Criterium | Table Extension | Nieuwe Tabel |
|-----------|----------------|--------------|
| Cardinality | 1:1 met base tabel | 1:N of N:M relatie |
| Veldaantal | 1–5 velden | Meer dan 5 velden |
| Zoekbaar in lijsten | Ja — veld direct op base page | Nee — via FactBox of lookup |
| Base tabel traffic | Laag (setup, master data) | Hoog (transacties) — ext vertraagt |
| Eigenaarschap | Verrijking van base data | Eigen domein-entiteit |
| Upgrade-risico | Hoger (afhankelijk van base) | Lager (eigen schema) |

**Vuistregels:**
- Zoekbaar/filterbaar in standaardlijsten → table extension
- Eigen lifecycle, eigen regels → nieuwe tabel + FlowField op base
- Transactietabellen (Sales Line, Item Ledger) → nooit extensie als het veel velden zijn

### Page Extension vs Nieuwe Page

| Criterium | Page Extension | Nieuwe Page |
|-----------|---------------|-------------|
| UX continuïteit | Velden verschijnen op bekende page | Nieuwe navigatie-stap |
| Veldaantal | 1–3 velden in groep | Veel velden of eigen layout |
| Actie | Eenvoudige actie-knop | Eigen workflow/wizard |
| Maintenance | Afhankelijk van base page wijzigingen | Onafhankelijk |

### Interface Pattern

```al
interface "MYAPP Document Processor"
{
    procedure Process(var DocumentHeader: Record "MYAPP Document Header");
    procedure Validate(DocumentHeader: Record "MYAPP Document Header"): Boolean;
}

codeunit 50500 "MYAPP Sales Processor" implements "MYAPP Document Processor"
{
    procedure Process(var DocumentHeader: Record "MYAPP Document Header")
    begin
        // Sales-specifieke logica
    end;

    procedure Validate(DocumentHeader: Record "MYAPP Document Header"): Boolean
    begin
        exit(DocumentHeader.Status = DocumentHeader.Status::Open);
    end;
}
```

**Wanneer interfaces:**
- Meerdere implementaties van dezelfde operatie (bijv. per document type)
- Dependency inversion voor testability
- Plugin-architectuur (andere apps leveren implementaties)

### Facade Codeunit Pattern

```al
codeunit 50501 "MYAPP Sales Facade"
{
    // Publieke API — stabiele signatures
    procedure CreateOrder(CustomerNo: Code[20]; var OrderNo: Code[20])
    begin
        OrderMgt.CreateSalesOrder(CustomerNo, OrderNo);
    end;

    procedure PostOrder(OrderNo: Code[20])
    begin
        PostingMgt.PostSalesOrder(OrderNo);
    end;

    var
        OrderMgt: Codeunit "MYAPP Order Management";
        PostingMgt: Codeunit "MYAPP Posting Management";
}
```

**Wanneer facade:**
- Externe apps subscriben of roepen jouw app aan
- Je wilt interne refactoring doen zonder signatures te breken
- API-laag over meerdere interne codeunits

### Setup Table Pattern

```al
table 50502 "MYAPP Setup"
{
    Caption = 'MYAPP Setup';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10]) { }
        field(10; "Enable Feature X"; Boolean)
        {
            Caption = 'Enable Feature X';
        }
        field(20; "Default Location Code"; Code[10])
        {
            Caption = 'Default Location Code';
            TableRelation = Location.Code;
        }
    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }

    procedure GetSetup()
    begin
        if not Get() then begin
            Init();
            Insert();
        end;
    end;
}
```

- Altijd `GetSetup()` helper — voorkomt "record not found" errors
- `Primary Key` = `Code[10]`, altijd leeg (singleton)
- `DataClassification = SystemMetadata` voor setup-velden

---

## Event Architectuur

### IntegrationEvent vs BusinessEvent

| Type | Gebruik | Signature wijzigen? |
|------|---------|-------------------|
| `[BusinessEvent]` | Formeel contract voor externe consumers (Power Automate, andere apps) | Nooit |
| `[IntegrationEvent]` | Intern extensiepunt voor andere AL-apps | Voorzichtig (breaking voor subscribers) |
| `[InternalEvent]` | Alleen binnen eigen app — vrij te wijzigen | Ja |

### Wanneer NIET subscriben

- **Performance:** subscriber op `OnBeforeModify` van Item of G/L Entry → elke posting wordt trager
- **Circulaire afhankelijkheid:** App A subscribed op App B die subscribed op App A
- **Impliciete koppeling:** subscriber die gedrag van base fundamenteel wijzigt zonder dat het zichtbaar is

### Event Sequencing

Subscribers hebben **geen gegarandeerde volgorde**. Als volgorde kritiek is:
- Gebruik één subscriber die intern de juiste volgorde afdwingt
- Of gebruik een priority-pattern met setup-tabel

---

## Multi-Tenant / SaaS Specifiek

### Niet beschikbaar in SaaS

| Feature | Alternatief |
|---------|-------------|
| Direct SQL access | AL record operations |
| `.NET` interop (`DotNet` type) | `HttpClient`, `JsonObject`, `XmlDocument` |
| File system access | `TempBlob`, `Isolated Storage`, Azure Blob via `HttpClient` |
| Registry access | `Isolated Storage` |
| Custom DLLs | AL native types of REST API calls |
| Windows events | `Session.LogMessage` → App Insights |

### Isolated Storage

```al
// Opslaan (per-tenant, encrypted)
IsolatedStorage.Set('ApiKey', ApiKeyValue, DataScope::Company);

// Ophalen
if IsolatedStorage.Get('ApiKey', DataScope::Company, ApiKeyValue) then
    // gebruik ApiKeyValue
```

| DataScope | Bereik |
|-----------|--------|
| `Module` | Per app installatie |
| `Company` | Per company |
| `User` | Per user |
| `CompanyAndUser` | Per user per company |

### Company-afhankelijke vs Database-brede data

- **Company-afhankelijk (standaard):** de meeste business data
- **Database-breed:** setup die voor alle companies geldt — gebruik `DataPerCompany = false` op de tabel

---

## Performance Architectuur

### FlowField vs Berekend Veld

| Criterium | FlowField | Code-berekening |
|-----------|-----------|-----------------|
| Actueel | Altijd (CalcFields) | Alleen bij aanroep |
| Performance | SIFT index nodig | Kan gebatched worden |
| Filters | Beperkt (CalcFormula) | Volledig flexibel |
| Sorteerbaar | Nee (via SetCurrentKey) | Ja (in temp tabel) |

**Vuistregel:** FlowField voor standaard aggregaties (saldo, aantal). Code voor complexe berekeningen of als je wilt sorteren.

### Key Design

```al
keys
{
    key(PK; "Document Type", "Document No.", "Line No.") { Clustered = true; }
    key(CustomerDate; "Sell-to Customer No.", "Posting Date") { }
    key(ItemLocation; "No.", "Location Code")
    {
        SumIndexFields = Quantity, "Amount (LCY)";
        MaintainSqlIndex = true;
        MaintainSiftIndex = true;
    }
}
```

**Wanneer extra keys:**
- Veld wordt gebruikt in `SetCurrentKey` + `FindSet` met >1000 records
- Veld wordt gebruikt in FlowField CalcFormula
- Combinatie wordt veel gebruikt in `SetRange` filters

**Wanneer NIET:**
- Tabel heeft <100 records
- Key wordt zelden gebruikt (insert-overhead)
- Tabel heeft al >5 keys (elke insert wordt trager)

### Bulk Operations

```al
// GOED — single SQL statement
SalesLine.ModifyAll(Status, SalesLine.Status::Released);

// SLECHT — row-by-row (maar nodig als je triggers/events wilt)
SalesLine.LockTable();
if SalesLine.FindSet() then
    repeat
        SalesLine.Status := SalesLine.Status::Released;
        SalesLine.Modify(true); // true = run triggers
    until SalesLine.Next() = 0;
```

`ModifyAll`/`DeleteAll` zijn veel sneller, MAAR:
- Geen triggers (`OnBeforeModify` etc.)
- Geen event subscribers
- Geen field validation

---

## Dependency Management

### app.json Dependencies

```json
{
    "dependencies": [
        {
            "id": "437dbf0e-84ff-417a-965d-ed2bb9650972",
            "name": "Base Application",
            "publisher": "Microsoft",
            "version": "24.0.0.0"
        },
        {
            "id": "12345678-...",
            "name": "My Other App",
            "publisher": "My Company",
            "version": "2.0.0.0"
        }
    ]
}
```

- `version` is **minimum** versie — BC installeert elke versie >= opgegeven
- Pin niet te specifiek (bijv. `24.5.12345.67890`) — breekt bij elke minor update
- Pin op major.minor: `24.0.0.0`

### Circular Dependency

**Detectie:** als App A dependency heeft op App B en App B op App A → compilatie faalt.

**Oplossing:**
1. Extract gemeenschappelijke types naar een derde app (shared library)
2. Gebruik events in plaats van directe dependency (App A publiceert event, App B subscribed)
3. Gebruik interfaces als contract (App A definieert interface, App B implementeert)

### Access Modifiers

```al
codeunit 50503 "MYAPP Internal Logic"
{
    Access = Internal; // alleen zichtbaar binnen eigen app
    
    procedure DoInternalWork()
    begin
        // niet aanroepbaar door andere apps
    end;
}

codeunit 50504 "MYAPP Public API"
{
    Access = Public; // default — zichtbaar voor alle apps
    
    procedure DoPublicWork()
    begin
        // aanroepbaar door alle apps met dependency
    end;
}
```

- `Internal`: vrij te refactoren zonder breaking changes
- `Public`: stabiele API — signature wijzigen is breaking
- **Vuistregel:** maak alles `Internal` tenzij het expliciet bedoeld is als API
