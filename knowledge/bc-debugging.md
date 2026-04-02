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

### Modi

| Modus | Wanneer | Overhead |
|-------|---------|----------|
| Instrumentation | Exacte timing per methode, call counts | Zwaar |
| Sampling (BC27+) | Lichtgewicht, toont ook SQL calls | Licht |

### launch.json

```json
{
    "executionContext": "Profile",
    "profilingType": "Sampling",
    "profileSamplingInterval": 100
}
```

### Workflow

1. Snapshot nemen met `executionContext=Profile`
2. Ctrl+Shift+P → "AL: Generate profile file"
3. `.alcpuprofile` opent in VS Code met top-down / bottom-up call stack
4. CodeLens toont inline timing en hit counts in broncode

### Gebruik profiler voor

- Pagina's die traag openen (filter op `OnOpenPage`/`OnAfterGetRecord`)
- Posting routines (`OnBeforePost`, `OnAfterPost` chains)
- Onderscheid AL-tijd vs SQL-tijd (sampling modus)

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
