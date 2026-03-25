# BC Dev Publish

Compileer en publiceer de AL-app naar de development server uit launch.json, via het BC Developer Services REST endpoint.

## Input

$ARGUMENTS — optionele instructies, bijvoorbeeld:
- (leeg) — standaard: compile + publish met ForceSync
- "synchronize" — gebruik SchemaUpdateMode=synchronize (niet-destructief)
- "alleen compileren" — compile zonder publish

## Instructies

### Stap 0 — Lees projectconfiguratie

1. Zoek het AL-project: de map met `app.json` (bijv. `BC Plants/app.json`).
2. Lees `app.json` → `name`, `publisher`, `version`.
3. Lees `<project>/.vscode/launch.json` → eerste configuratie met `type: "al"`:
   - `server` — BC server URL (bijv. `https://rzdm2`)
   - `serverInstance` — BC instance (bijv. `bc270`)
   - `tenant` — (default: `default`)
4. Lees `<project>/.vscode/settings.json` → `al.assemblyProbingPaths` array.
5. Lees credentials uit memory of CLAUDE.md.

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

### Stap 3 — Compileer

```bash
cd "<project>"
"$ALC" \
  /project:"." \
  /packagecachepath:".alpackages" \
  /out:"/tmp/bc-dev-publish.app" \
  /assemblyprobingpaths:"<komma-gescheiden bestaande paden>"
```

**Vereist:** `.alpackages/` moet gevuld zijn met platform symbols. Als leeg → stop ("draai eerst AL: Download Symbols in VS Code").

Bij compilatiefouten: toon errors en stop. Bij alleen warnings: ga door.

### Stap 4 — Publiceer via Dev Endpoint

```bash
curl -sk -X POST \
  "https://<hostname>:7049/<instance>/dev/apps?tenant=<tenant>&SchemaUpdateMode=<syncmode>" \
  -u "<username>:<password>" \
  -F "file=@/tmp/bc-dev-publish.app;type=application/octet-stream" \
  -w "\nHTTP %{http_code}"
```

- Gebruik ALTIJD `-F` (multipart), NOOIT `--data-binary` (geeft HTTP 415)
- `-sk` slaat SSL-validatie over (zelfondertekend cert op dev-servers)
- HTTP 200 = succes

Foutcodes: 401=credentials, 415=gebruik `-F`, 422=ForceSync proberen, connection refused=dev services uit.

### Stap 5 — Rapporteer

App naam/versie, server/instance, SchemaUpdateMode, succes of fout.

## Regels

- Gebruik ALTIJD het dev REST endpoint. Geen SSH, geen PowerShell, geen Publish-NAVApp.
- Lees ALTIJD `settings.json` voor assembly probing paths — raad ze niet.
- Gebruik ALTIJD `-F` voor de upload, NOOIT `--data-binary`.
- Filter ALTIJD probing paths op bestaan.
