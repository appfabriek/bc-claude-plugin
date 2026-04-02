---
name: dev-publish
description: Compile and publish AL app to BC dev server
bc-version: ">=14.0"
allowed-tools: Bash, Read, Write, Glob
---

# BC Dev Publish

Compileer en publiceer de AL-app naar de development server uit launch.json, via het BC Developer Services REST endpoint.

## Input

$ARGUMENTS — optionele instructies, bijvoorbeeld:
- (leeg) — standaard: compile + publish met ForceSync
- "synchronize" — gebruik SchemaUpdateMode=Synchronize (niet-destructief)
- "alleen compileren" — compile zonder publish
- "[configuratienaam]" — gebruik specifieke configuratie uit launch.json (bijv. "accept", "test")

## Instructies

### Stap 0 — Lees projectconfiguratie

1. Zoek het AL-project: de map met `app.json` (bijv. `BC Plants/app.json`).
2. Lees `app.json` → `name`, `publisher`, `version`.
3. Lees `<project>/.vscode/launch.json` → configuratie(s) met `type: "al"`:
   - Als er meerdere configuraties zijn en de gebruiker heeft geen naam opgegeven → vraag welke
   - Als er één is → gebruik die automatisch
   - Lees: `server`, `serverInstance`, `tenant` (default: `default`)
4. Lees `<project>/.vscode/settings.json` → `al.assemblyProbingPaths` array.
5. Lees credentials uit memory of CLAUDE.md.
6. Lees `al-guidelines.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin/knowledge ./.claude/plugins/bc-claude-plugin/knowledge ~/.local/share/claude/plugins/bc-claude-plugin/knowledge ~/code/bc-claude-plugin/knowledge -name "al-guidelines.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   voor context bij eventuele compilatiefouten.

### Stap 1 — Zoek de AL compiler

De compiler zit in de VS Code AL Language-extensie. Detecteer het platform automatisch:

```bash
case "$(uname -s)" in
  Darwin) PLATFORM="darwin" ;;
  Linux)  PLATFORM="linux" ;;
  *)      PLATFORM="win32" ;;
esac

ALC=$(find ~/.vscode/extensions -path "*/ms-dynamics-smb.al-*/bin/${PLATFORM}/alc" 2>/dev/null | sort -V | tail -1)

# Fallback: VS Code Insiders of Codium
if [ -z "$ALC" ]; then
  for dir in ~/.vscode-insiders/extensions ~/.vscode-oss/extensions; do
    ALC=$(find "$dir" -path "*/ms-dynamics-smb.al-*/bin/${PLATFORM}/alc" 2>/dev/null | sort -V | tail -1)
    [ -n "$ALC" ] && break
  done
fi
```

Als `alc` niet gevonden wordt → meld dit en stop.

Als de binary geen execute-rechten heeft op macOS:
```bash
chmod +x "$ALC"
```

### Stap 2 — Bouw assembly probing paths

Lees `al.assemblyProbingPaths` uit `settings.json`. Filter op paden die bestaan (`test -d`). Sla Windows-paden (`C:\...`) over.

Op macOS zijn .NET Framework 4.7.2 reference assemblies vereist. De standaardlocatie is `~/code/bc-claude-plugin/netframework-ref/v4.7.2` (zie README voor setup). Controleer of die map bestaat en voeg hem toe aan het begin als hij er is.

Voeg paden samen als komma-gescheiden string.

### Stap 3 — Check .alpackages

```bash
APP_COUNT=$(find "<project>/.alpackages" -name "*.app" 2>/dev/null | wc -l)
```

Als `APP_COUNT` = 0 → stop met foutmelding:
> `.alpackages/` is leeg — geen platform symbols gevonden. Open het project in VS Code en draai "AL: Download Symbols" (Ctrl+Shift+P) om de benodigde symbols te downloaden.

### Stap 4 — Compileer

```bash
cd "<project>"
"$ALC" \
  /project:"." \
  /packagecachepath:".alpackages" \
  /out:"/tmp/bc-dev-publish.app" \
  /assemblyprobingpaths:"<komma-gescheiden bestaande paden>"
```

Bij compilatiefouten: toon errors en stop. Bij alleen warnings: ga door.

### Stap 5 — Publiceer via Dev Endpoint

```bash
RESPONSE=$(curl -sk -X POST \
  "https://<hostname>:7049/<instance>/dev/apps?tenant=<tenant>&SchemaUpdateMode=<syncmode>" \
  -u "<username>:<password>" \
  -F "file=@/tmp/bc-dev-publish.app;type=application/octet-stream" \
  -w "\nHTTP_STATUS:%{http_code}" 2>&1)

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
```

- Gebruik ALTIJD `-F` (multipart), NOOIT `--data-binary` (geeft HTTP 415)
- `-sk` slaat SSL-validatie over (zelfondertekend cert op dev-servers)
- HTTP 200 = succes

**Foutcodes en acties:**
| Code | Oorzaak | Actie |
|------|---------|-------|
| 401 | Credentials onjuist | Check username/password in CLAUDE.md of memory |
| 415 | `--data-binary` gebruikt | Gebruik `-F` (multipart form) |
| 422 | Schema-conflict | Probeer `ForceSync` als SchemaUpdateMode |
| Connection refused | Dev services uit | "BC Developer Services staat uit op de server" |

### Stap 6 — Verifieer publicatie

Na een succesvolle publish (HTTP 200), verifieer dat de app daadwerkelijk draait:

```bash
curl -sk -u "<username>:<password>" \
  "https://<hostname>:7049/<instance>/dev/apps?tenant=<tenant>" \
  -H "Accept: application/json" 2>/dev/null | \
  python3 -c "
import sys, json
apps = json.load(sys.stdin)
for app in apps:
    if app.get('Name','') == '<app-name>':
        print(f\"Verified: {app['Name']} v{app['Version']} is active\")
" 2>/dev/null || echo "Publish succeeded (HTTP 200), verification skipped"
```

### Stap 7 — Rapporteer

Toon:
- App naam en versie (uit `app.json`)
- Server/instance (uit `launch.json`)
- SchemaUpdateMode gebruikt
- Succes of fout + actie
- Verificatie-resultaat

## Regels

- Gebruik ALTIJD het dev REST endpoint. Geen SSH, geen PowerShell, geen Publish-NAVApp.
- Lees ALTIJD `settings.json` voor assembly probing paths — raad ze niet.
- Gebruik ALTIJD `-F` voor de upload, NOOIT `--data-binary`.
- Filter ALTIJD probing paths op bestaan.
- Check ALTIJD of `.alpackages` gevuld is vóór compilatie.
