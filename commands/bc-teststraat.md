---
name: bc-teststraat
description: Zet een lokale BC teststraat op van nul tot werkend, of herstel een bestaande
bc-version: ">=27.0"
allowed-tools: Bash, Read, Write, Glob
---

# BC Teststraat

Opzetten, herstellen of resetten van de lokale BC testomgeving — van kaal systeem tot werkende testlus.

## Input

$ARGUMENTS — modus:
- (leeg) of `setup` — stel de teststraat in, sla al werkende stappen over
- `reset` — verwijder bestaande container en begin opnieuw
- `verify` — controleer de huidige staat zonder iets te wijzigen (zie ook `/bc-teststraat-verify`)
- `run` — draai de tests en toon de resultaten

## Instructies

### Stap 0 — Oriënteer jezelf

Lees `bc-local-dev.md` uit de knowledge/ map van de bc-claude-plugin voor achtergrond over de lokale BC-architectuur.

Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin/knowledge ./.claude/plugins/bc-claude-plugin/knowledge ~/.local/share/claude/plugins/bc-claude-plugin/knowledge ~/code/bc-claude-plugin/knowledge -name "bc-local-dev.md" 2>/dev/null | head -1`

Bepaal vervolgens de projectstructuur:

```bash
# Heeft dit project eigen bootstrap-scripts?
ls scripts/

# Centrale settings aanwezig?
ls config/*.settings.json 2>/dev/null || ls config/*.json 2>/dev/null

# Projectdocumentatie?
ls docs/teststraat.md docs/build.md 2>/dev/null
```

**Lees altijd `docs/teststraat.md`** als het bestaat — dit is de projectspecifieke bron van waarheid voor de lokale teststraat.

Detecteer het bootstrap-patroon:

| Wat je vindt | Patroon |
|---|---|
| `scripts/Initialize*TestLane*.ps1` | One-shot bootstrap aanwezig → gebruik die |
| `scripts/Setup*Environment*.ps1` | Modulaire setup aanwezig → gebruik die |
| Geen bootstrap-scripts | Generieke BcContainerHelper setup → zie Stap 3b |

### Stap 1 — Controleer en installeer vereisten

**Projectscript (als aanwezig):**
```powershell
# Draai als Administrator
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/InstallPrereqs.ps1
```

**Handmatig als geen script aanwezig:**

```powershell
# PowerShell 7
winget install --id Microsoft.PowerShell --silent

# Docker Desktop
winget install --id Docker.DockerDesktop --silent

# Windows-features (vereist reboot als ze nog niet aan staan)
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All, Containers -All -NoRestart

# BcContainerHelper
Install-Module BcContainerHelper -Force -Scope CurrentUser
```

> **Na activatie van Hyper-V / Containers**: herstart Windows, start Docker Desktop, wacht tot het icoon in de taakbalk stabiel is.

**Verifieer Docker in Windows-container mode:**
```powershell
docker version --format "{{.Server.Os}}"   # verwacht: windows
```

Staat Docker in Linux mode? Switch:
```powershell
& 'C:\Program Files\Docker\Docker\DockerCli.exe' -SwitchWindowsEngine
```

### Stap 2 — Maak de BC container

**Projectscript (als aanwezig):**
```powershell
pwsh -NoLogo -NoProfile -File scripts/New-Bc*Container*.ps1
# Met reset: ... -Recreate
```

**Generiek (als geen projectscript aanwezig):**

Bepaal eerst de artifact URL. Zoek in het project:
```bash
grep -r "artifactUrl\|bcartifacts" .AL-Go/settings.json scripts/ config/ 2>/dev/null | head -5
```

Of gebruik BcContainerHelper om de laatste BC27 te vinden:
```powershell
$artifactUrl = Get-BcArtifactUrl -type OnPrem -version "27" -country nl -select Latest
```

Maak de container:
```powershell
Import-Module BcContainerHelper

$credential = [PSCredential]::new("admin",
    (ConvertTo-SecureString "Admin@1234!" -AsPlainText -Force))

New-BcContainer `
    -accept_eula `
    -accept_outdated `
    -containerName "bc-dev" `
    -artifactUrl $artifactUrl `
    -auth NavUserPassword `
    -Credential $credential `
    -licenseFile "license/<jouw-licentie>.bclicense" `
    -includeTestToolkit `
    -updateHosts `
    -locale nl-NL
```

> **Licentiebestand**: vereist een BC Developer-licentie. Controleer de `license/` map in de repo. Ontbreekt die? Vraag de projectbeheerder.

### Stap 3 — Bootstrap de testomgeving

Dit is de project-specifieke stap. Volg één van onderstaande paden:

#### Stap 3a — Projectscript gebruiken (aanbevolen)

Als het project een bootstrapscript heeft:
```powershell
pwsh -NoLogo -NoProfile -File scripts/Setup-Bc*Environment*.ps1
```

Lees `docs/teststraat.md` voor wat dit script doet en welke configuratie-overrides van toepassing zijn.

#### Stap 3b — Generiek bootstrappen (als geen script aanwezig)

Voer de volgende stappen handmatig uit via BcContainerHelper. Lees `bc-local-dev.md` (uit de plugin knowledge) voor uitleg per stap.

**1. Wacht tot BC-service running is:**
```powershell
$timeout = (Get-Date).AddMinutes(6)
do {
    $status = (Get-BcContainerServerConfiguration $containerName).ServiceStatus
    Start-Sleep -Seconds 10
} while ($status -ne 'Running' -and (Get-Date) -lt $timeout)
```

**2. Kopieer .NET assemblies (alleen als project `.netpackages/` heeft):**
```powershell
$netDir = Get-ChildItem -Path . -Filter ".netpackages" -Recurse -Directory | Select-Object -First 1
if ($netDir) {
    $addInsTarget = "C:\Program Files\Microsoft Dynamics NAV\270\Service\Add-ins"
    Get-ChildItem $netDir.FullName -Filter "*.dll" | ForEach-Object {
        Copy-FileToBcContainer -containerName $containerName `
            -localPath $_.FullName `
            -containerPath (Join-Path $addInsTarget $_.Name)
    }
    Restart-BcContainerServiceTier -containerName $containerName
}
```

**3. Publiceer dependency apps:**
```powershell
# Zoek dependency apps
$deps = Get-ChildItem -Path "connections", "dependencyapps" -Filter "*.app" -ErrorAction SilentlyContinue
foreach ($dep in $deps) {
    Publish-BcContainerApp -containerName $containerName -appFile $dep.FullName `
        -skipVerification -sync -install
}
```

**4. Bouw en publiceer de hoofdapp:**
```powershell
# Via projectscript als dat bestaat:
pwsh scripts/Build-App.ps1

# Of rechtstreeks met BcContainerHelper:
$appFile = Compile-AppInBcContainer -containerName $containerName `
    -appProjectFolder (Get-Location).Path
Publish-BcContainerApp -containerName $containerName -appFile $appFile `
    -skipVerification -sync -install
```

**5. Maak een testgebruiker aan:**
```powershell
New-BcContainerBCUser -containerName $containerName `
    -username "TESTUSER" `
    -password (ConvertTo-SecureString "Test@1234!" -AsPlainText -Force) `
    -PermissionSetId SUPER
```

### Stap 4 — Draai de tests

**Projectscript (aanbevolen):**
```powershell
pwsh -NoLogo -NoProfile -File scripts/Run-Bc*Tests*.ps1
```

**Generiek via BcContainerHelper:**
```powershell
Run-TestsInBcContainer `
    -containerName $containerName `
    -credential $testCredential `
    -XUnitResultFileName ".artifacts/test-results/results.xunit.xml" `
    -detailed
```

**Bekijk de laatste resultaten:**
```powershell
$latest = Get-ChildItem .artifacts/test-results -Directory |
    Where-Object Name -match '^\d{8}-' |
    Sort-Object Name | Select-Object -Last 1
Get-Content "$($latest.FullName)/summary.md" -ErrorAction SilentlyContinue
```

### One-shot bootstrap

Als het project een `Initialize*TestLane*.ps1` heeft:
```powershell
pwsh -NoLogo -NoProfile -File scripts/Initialize-Bc*TestLane*.ps1 -RunTests
# Met container reset: ... -RecreateContainer -RunTests
```

## Dagelijkse werkcyclus

```
code schrijven / test aanpassen
↓
pwsh scripts/Run-Bc*Tests*.ps1
↓
.artifacts/test-results/<timestamp>/summary.md lezen
↓
herhalen
```

Alleen de hoofdapp verversen zonder tests:
```powershell
pwsh scripts/Setup-Bc*Environment*.ps1
```

## Probleemoplossing

| Symptoom | Oorzaak | Oplossing |
|---|---|---|
| `docker: command not found` | Docker Desktop niet gestart | Start Docker Desktop |
| `docker: windows containers required` | Docker staat in Linux mode | `DockerCli.exe -SwitchWindowsEngine` |
| `License file not found` | Licentie ontbreekt | Controleer `license/` map |
| `AL1022: package not found` | `.alpackages` niet gevuld | `pwsh scripts/Download-Symbols.ps1` |
| `AL0451: assembly not found` | .NET DLL's niet in Add-Ins | Herrun environment bootstrap |
| Tests compileren niet | Versie-mismatch | Herrun de test-runner (herstelt automatisch) |
| Container stale na settings-wijziging | Oude container | Bootstrap-script met `-Recreate` flag |
| BC-service start niet | Licentie verlopen of image-probleem | Controleer licentiedatum; vervang container |

## Regels

- Lees altijd `docs/teststraat.md` als dat bestaat — dat is leidend boven deze generieke skill
- Draai `InstallPrereqs.ps1` altijd als Administrator
- Herstart Windows wanneer het script dat aangeeft — sla dit niet over
- Start Docker Desktop handmatig na elke herstart
- De `sourceBuildCompatibilityPatches` (als aanwezig) worden ALLEEN op staging-kopieën toegepast — nooit op de echte broncode
- Gebruik de centrale settings-override (bijv. `config/teststraat.settings.json`) — bewerk helper-scripts nooit direct
