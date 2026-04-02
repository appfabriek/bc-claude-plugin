---
name: bc-env
description: Inspect BC environment - installed apps, versions, compare environments
bc-version: ">=14.0"
---

# BC Environment

Inspecteer een BC-omgeving: geïnstalleerde apps, versies, status. Voor developers en consultants.

## Input

$ARGUMENTS — optionele instructies, bijvoorbeeld:
- (leeg) — toon installed extensions op de dev-omgeving uit launch.json
- "accept" of "[configuratienaam]" — gebruik specifieke configuratie uit launch.json
- "alle" — toon voor alle configuraties in launch.json
- "vergelijk dev accept" — vergelijk extensies tussen twee omgevingen

## Instructies

### Stap 0 — Lees projectconfiguratie

1. Zoek het AL-project: de map met `app.json`.
2. Lees `<project>/.vscode/launch.json` → alle configuraties met `type: "al"`.
3. Lees credentials uit memory of CLAUDE.md.

### Stap 1 — Bepaal omgeving(en)

- Als de gebruiker een configuratienaam heeft opgegeven → gebruik die
- Als er maar één configuratie is → gebruik die automatisch
- Als er meerdere zijn en geen naam opgegeven → vraag de gebruiker
- Bij "alle" → doorloop alle configuraties sequentieel

Uit elke configuratie: `server` (hostname), `serverInstance`, `tenant` (default: `default`).

### Stap 2 — Haal installed extensions op

**Via de BC Automation API:**

```bash
curl -sk -u "<username>:<password>" \
  "https://<hostname>:7049/<instance>/api/microsoft/automation/v2.0/companies?tenant=<tenant>" \
  -H "Accept: application/json"
```

Uit de response: pak de eerste company ID (of filter op company-naam als opgegeven).

```bash
curl -sk -u "<username>:<password>" \
  "https://<hostname>:7049/<instance>/api/microsoft/automation/v2.0/companies(<company-id>)/extensions?tenant=<tenant>" \
  -H "Accept: application/json"
```

**Fallback — via Dev Endpoint:**
Als de Automation API niet beschikbaar is:

```bash
curl -sk -u "<username>:<password>" \
  "https://<hostname>:7049/<instance>/dev/apps?tenant=<tenant>" \
  -H "Accept: application/json"
```

### Stap 3 — Presenteer resultaat

Sorteer op publisher, dan op naam:

```
## Omgeving: dev (https://rzdm2:7049/bc270)

### Appfabriek (eigen apps)
| App                  | Versie       | Status    |
|----------------------|-------------|-----------|
| Agrio Connections    | 4.0.1.20    | Installed |
| Plants Extension     | 1.2.3.0     | Installed |

### Microsoft
| App                  | Versie       |
|----------------------|-------------|
| Base Application     | 24.0.12345.0 |
| System Application   | 24.0.12345.0 |
| ...                  | ...         |

### Overige publishers
| App                  | Publisher    | Versie       |
|----------------------|-------------|-------------|
| ...                  | ...         | ...         |
```

Markeer eigen apps (Appfabriek / publisher uit `app.json`) apart bovenaan.

### Stap 4 — Vergelijking (bij "vergelijk")

Als twee omgevingen vergeleken worden:

```
## Vergelijking: dev vs accept

| App                  | dev          | accept       | Status       |
|----------------------|-------------|-------------|--------------|
| Plants Extension     | 1.2.4.0     | 1.2.3.0     | dev is nieuwer |
| Agrio Connections    | 4.0.1.20    | 4.0.1.20    | gelijk       |
| New Feature App      | 1.0.0.0     | —           | alleen dev   |
```

## Regels

- Gebruik ALTIJD `-sk` voor SSL (zelfondertekende certs op dev-servers)
- Credentials uit memory of CLAUDE.md, niet hardcoded
- Bij connection refused: meld "BC server is niet bereikbaar — check of de service draait"
- Bij 401: meld "Credentials worden niet geaccepteerd — check username/password"
- Toon Microsoft-systeem-apps optioneel (standaard alleen als er weinig apps zijn of de gebruiker specifiek vraagt)
