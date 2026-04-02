# BC Debugging & Profiling

## Drie debugmodi

| Modus | Wanneer | Vereiste |
|-------|---------|---------|
| Classic (F5) | Dev/sandbox, eigen code | launch.json type=al, port 7049 |
| Attach (F5) | Lopende sessie bijvoegen | sessionId in launch.json |
| Snapshot | Productie, SaaS, moeilijk te reproduceren bugs | D365 SNAPSHOT DEBUG permissie |

---

## Snapshot Debugging

### launch.json configuratie

```json
{
    "name": "Snapshot: productie",
    "type": "al",
    "request": "snapshotInitialize",
    "environmentType": "Sandbox",
    "server": "https://api.businesscentral.dynamics.com",
    "serverInstance": "BC",
    "authentication": "AAD",
    "breakOnNext": "WebClient",
    "userId": "<AAD-guid-van-gebruiker>",
    "sessionId": "<optioneel-sessie-id>"
}
```

### Workflow

1. **F7** → snapshot sessie starten (30 minuten window)
2. Gebruiker voert de actie uit in BC
3. **Alt+F7** → sessie stoppen, snapshot downloadt naar `.snapshots/`
4. **Shift+F7** → snapshot openen en debuggen (offline, zonder serververbinding)

### Valkuilen

- Symbolen op server moeten matchen met lokale symbolen → altijd Download Symbols van de exacte omgeving vóór snapshot sessie
- `allowDebugging=false` op externe apps → code is niet stap-voor-stap te volgen
- Snapshot max 30 minuten actief, max bestandsgrootte ~500MB
- `applyToDevExtension=true` overschrijft `resourceExposurePolicy`

---

## AL Profiler

Twee modi:
- **Instrumentation** (standaard): exacte timing per methode, call counts. Zwaarder maar precies. Gebruik voor: isoleren van trage procedures.
- **Sampling** (BC27+): lichtgewicht, toont ook SQL calls. Gebruik voor: eerste oriëntatie op een performance-probleem.

### launch.json configuratie

```json
{
    "name": "Profile: productie",
    "type": "al",
    "request": "snapshotInitialize",
    "environmentType": "Sandbox",
    "breakOnNext": "WebClient",
    "executionContext": "Profile",
    "profilingType": "Sampling",
    "profileSamplingInterval": 100
}
```

`executionContext` opties:
- `"DebugAndProfile"` — debug én profile tegelijk
- `"Profile"` — alleen profiling, geen breakpoints

### Workflow

1. Start snapshot sessie met **F7** (`executionContext` moet `"Profile"` zijn)
2. Gebruiker voert de trage actie uit in BC
3. **Alt+F7** — sessie stoppen, snapshot downloadt naar `.snapshots/`
4. Ctrl+Shift+P → "AL: Generate profile file" → kies snapshot
5. `.alcpuprofile` opent automatisch in de VS Code performance editor

### Performance Editor

- **Top-down view:** startpunt → geneste aanroepen. Gebruik voor: "wat roept mijn trage procedure aan"
- **Bottom-up view:** duurste procedures bovenaan. Gebruik voor: "wat kost de meeste tijd"
- **Self time:** tijd in de procedure zelf (zonder child calls)
- **Total time:** inclusief alle geneste aanroepen
- **CodeLens:** na profiling toont VS Code inline timing naast procedure-headers

### BC27+ Sampling met SQL tracking

Bij `profilingType: "Sampling"` zie je ook welke SQL calls gemaakt zijn. Onderscheid: is de bottleneck AL-code of database queries? Kijk in de profile view naar SQL-gerelateerde frames.

### Vuistregels

- Trage page-opening → filter op `OnOpenPage`, `OnAfterGetRecord`
- Trage posting → filter op `OnBeforePost`, `OnAfterPost` chains
- Veel kleine SQL calls → N+1 probleem, gebruik `SetLoadFields` of bulk
- Hoge total time, lage self time → probleem zit dieper in de call stack

---

## SQL Debugging

In launch.json: `"enableSQLInformationDebugger": true`

In VARIABLES venster → `<Database statistics>` node toont:
- Netwerklatency server ↔ database
- Totaal SQL statements
- Totaal rijen gelezen
- Locks gehouden
- Meest recente SQL statements

Gebruik dit om N+1 query problemen te detecteren.

---

## Veelgemaakte Debugfouten

| Probleem | Oorzaak | Oplossing |
|----------|---------|-----------|
| Breakpoint raakt nooit | Symbolen niet gesynchroniseerd | Download Symbols opnieuw |
| "External code" niet debugbaar | Publisher heeft `allowDebugging=false` | Vraag publisher om debug-versie |
| Snapshot start niet | Gebruiker heeft geen D365 SNAPSHOT DEBUG permissie | Wijs permissie toe |
| In-client debugger | BC26+: Explore page → Open VS Code | Installeer VS Code extensie |
| Variabelen niet zichtbaar | Compiler optimalisatie | Voeg variabele toe aan watch of gebruik het in code |
