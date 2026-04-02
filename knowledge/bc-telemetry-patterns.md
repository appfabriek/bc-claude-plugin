# BC Telemetry Patterns

Patronen voor Application Insights telemetry in BC extensions.

---

## Session.LogMessage

```al
Session.LogMessage(
    'MYAPP-0001',                    // EventId — uniek per event
    'Sales order posted successfully', // Message
    Verbosity::Normal,                // Severity
    DataClassification::SystemMetadata, // Classification
    TelemetryScope::ExtensionPublisher, // Scope
    'OrderNo', SalesHeader."No.",    // Custom dimension 1
    'CustomerNo', SalesHeader."Sell-to Customer No." // Custom dimension 2
);
```

### Parameters

| Parameter | Waarden |
|-----------|---------|
| EventId | `'PREFIX-NNNN'` — uniek, stabiel, zoekbaar in KQL |
| Message | Beschrijvend, geen PII |
| Verbosity | `Critical`, `Error`, `Warning`, `Normal`, `Verbose` |
| DataClassification | `SystemMetadata` (geen PII), `CustomerContent`, `EndUserIdentifiable` |
| TelemetryScope | `ExtensionPublisher` (jouw App Insights), `All` (ook Microsoft) |
| Custom dimensions | Max 8 key-value pairs |

---

## EventId Conventie

```
PREFIX-AREA-NNNN

Voorbeelden:
MYAPP-SALES-0001    Sales order posted
MYAPP-SALES-0002    Sales order posting failed
MYAPP-PURCH-0001    Purchase order received
MYAPP-SETUP-0001    Setup wizard completed
MYAPP-API-0001      API call received
MYAPP-API-0002      API call failed
MYAPP-COPILOT-0001  Copilot suggestion generated
```

Houd een register bij in je project (bijv. `docs/telemetry-events.md`).

---

## Waar Telemetry Toevoegen

### Kritieke paden (verplicht)

```al
// Na succesvolle posting
Session.LogMessage('MYAPP-SALES-0001', 'Sales order posted',
    Verbosity::Normal, DataClassification::SystemMetadata,
    TelemetryScope::ExtensionPublisher,
    'OrderNo', SalesHeader."No.",
    'Amount', Format(TotalAmount));

// Bij fouten
Session.LogMessage('MYAPP-SALES-0002', 'Sales order posting failed',
    Verbosity::Error, DataClassification::SystemMetadata,
    TelemetryScope::ExtensionPublisher,
    'OrderNo', SalesHeader."No.",
    'Error', GetLastErrorText());

// Externe integratie calls
Session.LogMessage('MYAPP-API-0001', 'External API call',
    Verbosity::Normal, DataClassification::SystemMetadata,
    TelemetryScope::ExtensionPublisher,
    'Endpoint', ApiUrl,
    'StatusCode', Format(HttpStatusCode));
```

### Optionele paden (aanbevolen)

- Setup wizard stappen
- Copilot capability gebruik
- Job Queue start/einde
- Upgrade codeunit stappen
- Feature adoption (eerste gebruik van een feature)

---

## Custom Dimensions

Standaard BC custom dimensions (automatisch beschikbaar in KQL):

| Dimensie | Waarde |
|----------|--------|
| `al_objectId` | Object ID van de caller |
| `al_objectName` | Object naam |
| `al_companyName` | Company naam |
| `al_tenantId` | Tenant ID |
| `al_clientType` | Web, Phone, Tablet, API, Background |
| `al_environmentName` | Environment naam (SaaS) |
| `al_environmentType` | Production, Sandbox |

Eigen custom dimensions (max 8 per LogMessage):
- Gebruik **geen PII** in dimensions die naar `SystemMetadata` gaan
- Keys: camelCase, beschrijvend (`orderNo`, `customerNo`, `apiEndpoint`)
- Values: korte strings, geen grote JSON blobs

---

## KQL Queries (Application Insights)

### Fouten per dag

```kql
traces
| where timestamp > ago(7d)
| where customDimensions.eventId startswith "MYAPP-"
| where severityLevel >= 3  // Error + Critical
| summarize ErrorCount = count() by bin(timestamp, 1d), tostring(customDimensions.eventId)
| render timechart
```

### Slowste operaties

```kql
traces
| where timestamp > ago(24h)
| where customDimensions.eventId startswith "MYAPP-"
| extend Duration = todecimal(customDimensions.durationMs)
| where Duration > 1000
| project timestamp, customDimensions.eventId,
    customDimensions.al_objectName, Duration
| order by Duration desc
| take 50
```

### Feature adoption

```kql
traces
| where timestamp > ago(30d)
| where customDimensions.eventId == "MYAPP-COPILOT-0001"
| summarize Users = dcount(tostring(customDimensions.al_tenantId)) by bin(timestamp, 1d)
| render timechart
```

### User activity

```kql
traces
| where timestamp > ago(7d)
| where customDimensions.eventId startswith "MYAPP-"
| where severityLevel == 1  // Normal
| summarize Actions = count() by tostring(customDimensions.al_companyName)
| order by Actions desc
```

### Error details

```kql
traces
| where timestamp > ago(24h)
| where customDimensions.eventId == "MYAPP-SALES-0002"
| project timestamp,
    OrderNo = tostring(customDimensions.orderNo),
    Error = tostring(customDimensions.Error),
    Company = tostring(customDimensions.al_companyName)
| order by timestamp desc
```

---

## App Insights Setup

### SaaS (Dynamics 365 Business Central Online)

1. Maak een Azure Application Insights resource
2. Kopieer de **Connection String** (niet Instrumentation Key — die is deprecated)
3. In BC Admin Center → Environment → Telemetry → voeg Connection String toe
4. Per-app telemetry: vul Connection String in `app.json`:

```json
{
    "applicationInsightsConnectionString": "InstrumentationKey=...;IngestionEndpoint=..."
}
```

### On-Prem

1. Zelfde Azure Application Insights setup
2. In `CustomSettings.config` of BC Admin Shell:
   ```
   Set-NAVServerConfiguration -ServerInstance BC -KeyName ApplicationInsightsConnectionString -KeyValue "InstrumentationKey=..."
   ```
3. Per-app: zelfde `app.json` methode als SaaS

---

## Performance Counters

BC stuurt automatisch performance data naar App Insights:

| Signal | KQL tabel | Voorbeeld |
|--------|-----------|-----------|
| Long running SQL | `traces` | Query > 1000ms |
| AL function timing | `traces` | Functie > 5000ms |
| HTTP calls | `dependencies` | Web service calls |
| Page views | `pageViews` | Welke pages worden bezocht |
| Exceptions | `exceptions` | Runtime errors |

---

## Valkuilen

- **Geen PII in SystemMetadata:** namen, e-mails, telefoonnummers → gebruik `CustomerContent` classification
- **EventId stabiel houden:** wijzig nooit een EventId na release — KQL queries breken
- **Niet te veel loggen:** elke LogMessage kost geld in App Insights; log alleen wat je analyseert
- **Verbosity::Verbose** alleen voor debugging — zet niet standaard aan in productie
