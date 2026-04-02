---
name: bc-telemetry
description: Add telemetry, review coverage, and generate KQL queries
bc-version: ">=18.0"
---

# BC Telemetry

Voeg Application Insights telemetry toe, review dekking, of genereer KQL queries.

## Input

$ARGUMENTS — modus:
- "--add [codeunit]" — voeg Session.LogMessage toe aan een codeunit
- "--review" — scan project op ontbrekende telemetry
- "--kql [event-type]" — genereer KQL query

## Instructies

### Stap 0 — Laad kennis

1. Lees `knowledge/bc-telemetry-patterns.md` voor LogMessage syntax, EventId conventie, KQL templates.
2. Lees `knowledge/al-guidelines.md` voor naamgeving.
3. Lees `app.json` → check of `applicationInsightsConnectionString` is ingesteld.

### Modus: --add [codeunit]

1. Lees de opgegeven codeunit
2. Identificeer kritieke paden:
   - Posting/processing procedures (succes + falen)
   - Externe API calls (request + response)
   - Error-afhandeling (TryFunction catch)
   - Setup/configuratie wijzigingen
3. Voeg `Session.LogMessage` toe na elke kritiek pad:
   ```al
   Session.LogMessage('<PREFIX>-<AREA>-<NNNN>', '<beschrijving>',
       Verbosity::Normal, DataClassification::SystemMetadata,
       TelemetryScope::ExtensionPublisher,
       '<key1>', <value1>, '<key2>', <value2>);
   ```
4. Kies Verbosity per situatie:
   - `Normal`: succesvolle operaties
   - `Error`: gefaalde operaties
   - `Warning`: onverwachte maar niet-fatale situaties
   - `Verbose`: debug-informatie (niet standaard aan)

### Modus: --review

1. Scan alle AL-bestanden in het project
2. Zoek naar `Session.LogMessage` calls
3. Identificeer kritieke paden ZONDER telemetry:
   - Posting codeunits zonder succes/faal logging
   - Externe HTTP calls zonder timing/status logging
   - TryFunction blocks zonder error logging
   - Install/Upgrade codeunits zonder stap-logging
4. Rapporteer per bestand met suggestie waar LogMessage toegevoegd moet worden

### Modus: --kql [event-type]

1. Lees `knowledge/bc-telemetry-patterns.md` voor KQL templates
2. Genereer een kant-en-klare KQL query op basis van het gevraagde:
   - "errors" → fouten per dag timechart
   - "performance" → slowste operaties
   - "usage" → feature adoption
   - "users" → user activity per company
   - Custom EventId → query op specifiek event

## Regels

- EventId format: `PREFIX-AREA-NNNN` — stabiel, nooit wijzigen na release
- Geen PII in `SystemMetadata` classificatie
- Max 8 custom dimensions per LogMessage
- `TelemetryScope::ExtensionPublisher` voor eigen App Insights
- Lees `knowledge/bc-telemetry-patterns.md` voor alle conventies
