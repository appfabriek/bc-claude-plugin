---
name: bc-teststraat-verify
description: Diagnoseer de staat van de lokale BC teststraat zonder iets te wijzigen
bc-version: ">=27.0"
allowed-tools: Bash, Read
---

# BC Teststraat Verify

Controleer de staat van de lokale teststraat en rapporteer wat werkt, wat ontbreekt, en wat de volgende stap is.

## Input

$ARGUMENTS — optioneel filterwoord:
- (leeg) — volledige diagnose
- `quick` — alleen Docker + container status, geen app-checks

## Instructies

### Stap 1 — Systeem en Docker

```powershell
# PowerShell versie
$PSVersionTable.PSVersion

# Docker draait?
docker version --format "{{.Server.Os}}" 2>&1
# Verwacht: windows

# Docker in Windows-container mode?
docker info --format "{{.OSType}}" 2>&1
# Verwacht: windows
```

**Status:** ✓ / ✗ voor elk onderdeel.

### Stap 2 — Container

```powershell
# Container bestaat en draait?
docker ps --filter "name=bcplants-test" --format "{{.Names}} {{.Status}}"

# BC-service status in container
docker exec bcplants-test powershell -Command "
  (Get-Service -Name 'MicrosoftDynamicsNavServer`$BC270' -ErrorAction SilentlyContinue).Status
"
```

**Status:** ✓ Container running / ✗ Container absent / ⚠ Container exists but stopped

### Stap 3 — .NET assemblies in Add-Ins

```powershell
docker exec bcplants-test powershell -Command "
  \$addins = 'C:\Program Files\Microsoft Dynamics NAV\270\Service\Add-ins'
  @('MySql.Data.dll','NM_2_0_0_3.dll','Signature.dll','nmSocket.dll') | ForEach-Object {
    \$path = Join-Path \$addins \$_
    [pscustomobject]@{ File = \$_; Present = (Test-Path \$path) }
  } | Format-Table -AutoSize
"
```

**Status:** ✓ / ✗ per assembly. Ontbrekende assemblies veroorzaken AL0451-fouten.

### Stap 4 — Gepubliceerde apps in de container

```powershell
docker exec bcplants-test powershell -Command "
  Import-Module 'C:\Program Files\Microsoft Dynamics NAV\270\Service\Microsoft.Dynamics.Nav.Management.dll'
  Get-NAVAppInfo -ServerInstance BC270 -Tenant default |
    Select-Object Name, Version, Status |
    Format-Table -AutoSize
"
```

Verwachte apps:
| App | Verwacht |
|---|---|
| Agrio Connections | Installed |
| BC Plants | Installed |
| Test Runner | Installed (als includeTestToolkit=true) |

**Status:** ✓ / ✗ / ⚠ (aanwezig maar andere versie) per app.

### Stap 5 — Build-omgeving

```powershell
# alc.exe beschikbaar?
$alcPath = Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Recurse -Filter 'alc.exe' -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
$alcPath

# .alpackages gevuld?
(Get-ChildItem 'BC Plants/.alpackages' -Filter '*.app' -ErrorAction SilentlyContinue).Count

# Agrio Connections symbols aanwezig?
Test-Path 'BC Plants/.alpackages/Newminds_Agrio Connections_*.app'
```

**Status:** ✓ / ✗ voor alc.exe en symbol packages.

### Stap 6 — Laatste testresultaten

```powershell
$resultsRoot = '.artifacts/test-results'
$latest = Get-ChildItem $resultsRoot -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match '^\d{8}-' } |
  Sort-Object Name | Select-Object -Last 1

if ($latest) {
  $summary = Join-Path $latest.FullName 'summary.md'
  if (Test-Path $summary) { Get-Content $summary }
} else {
  Write-Host "Geen testresultaten gevonden"
}
```

### Stap 7 — Conclusie en aanbeveling

Rapporteer als tabel:

| Component | Status | Actie |
|---|---|---|
| Docker (Windows mode) | ✓/✗ | — / Start Docker + switch mode |
| Container `bcplants-test` | ✓/✗/⚠ | — / `/bc-teststraat setup` / `-Recreate` |
| BC-service | ✓/✗ | — / Herstart container |
| .NET assemblies | ✓/✗ | — / `Setup-BcPlantsTestEnvironment.ps1` |
| Agrio Connections | ✓/✗ | — / `Setup-BcPlantsTestEnvironment.ps1` |
| BC Plants | ✓/✗ | — / `Setup-BcPlantsTestEnvironment.ps1` |
| alc.exe | ✓/✗ | — / AL VS Code extensie installeren |
| Symbol packages | ✓/✗ | — / `Download-Symbols.ps1` |
| Laatste testrun | ✓/✗/geen | — / — / `/bc-teststraat run` |

**Aanbeveling:**
- Alles ✓ → teststraat is gezond, gebruik `/bc-teststraat run` om tests te draaien
- Eén of meer ✗ → geef het exacte commando om het te herstellen
- Container ✗ maar rest ✓ → `pwsh scripts/New-BcPlantsTestContainer.ps1`
- Meerdere ✗ → `pwsh scripts/Initialize-BcPlantsTestLane.ps1 -RunTests`

## Regels

- Wijzig niets — alleen lezen en rapporteren
- Gebruik concrete ✓/✗/⚠ symbolen in de output, geen proza
- Geef altijd één concreet commando als aanbeveling, niet een lijst van opties
