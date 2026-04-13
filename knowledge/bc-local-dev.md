# BC Local Development Environment

Kennis over het opzetten en beheren van een lokale BC ontwikkel- en testomgeving met Docker en BcContainerHelper.

---

## Architectuur

Een lokale BC teststraat bestaat uit vier lagen:

```
┌─────────────────────────────────────────────┐
│  Test runner (Run-TestsInBcContainer)        │
├─────────────────────────────────────────────┤
│  Gepubliceerde apps                          │
│  - Test extensie                             │
│  - Hoofdapp (BC Plants / jouw app)           │
│  - Dependency apps (Agrio Connections, etc.) │
├─────────────────────────────────────────────┤
│  BC container (Docker, Windows containers)   │
│  - BC Service Tier (BC270 / BC27)            │
│  - Add-Ins map (.NET assemblies)             │
│  - Test Toolkit (Library Assert, Runner)     │
├─────────────────────────────────────────────┤
│  Host: Windows + Docker Desktop              │
│  BcContainerHelper PowerShell module         │
└─────────────────────────────────────────────┘
```

**Volgorde is verplicht**: vereisten → container → .NET assemblies → dependency apps → hoofdapp → tests. Elke laag bouwt op de vorige.

---

## Vereiste software

| Software | Minimale versie | Installatie |
|---|---|---|
| Windows | 10 Pro / 11 | — |
| PowerShell | 7.x (`pwsh`) | `winget install Microsoft.PowerShell` |
| Docker Desktop | Actueel | `winget install Docker.DockerDesktop` |
| Windows-features | — | `Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All, Containers -All` |
| BcContainerHelper | 6.x | `Install-Module BcContainerHelper -Force -Scope CurrentUser` |
| GitHub CLI | Actueel | `winget install GitHub.cli` (optioneel) |

> **Kritiek**: Docker Desktop moet in **Windows-container mode** staan. BC-containers zijn Windows containers — Linux mode werkt niet.

```powershell
# Controleer
docker version --format "{{.Server.Os}}"   # verwacht: windows

# Switch naar Windows mode
& 'C:\Program Files\Docker\Docker\DockerCli.exe' -SwitchWindowsEngine
```

---

## BC container aanmaken

BcContainerHelper beheert de volledige container lifecycle:

```powershell
Import-Module BcContainerHelper

$credential = [PSCredential]::new("admin",
    (ConvertTo-SecureString "Admin@12345!" -AsPlainText -Force))

# Vind de juiste artifact URL
$artifactUrl = Get-BcArtifactUrl -type OnPrem -version "27" -country nl -select Latest

New-BcContainer `
    -accept_eula `
    -accept_outdated `
    -containerName "bc-dev" `
    -artifactUrl $artifactUrl `
    -auth NavUserPassword `
    -Credential $credential `
    -licenseFile "license/myapp.bclicense" `
    -includeTestToolkit `    # importeert Test Toolkit automatisch
    -updateHosts `           # voegt container toe aan hosts-bestand
    -locale nl-NL
```

### Veelgebruikte parameters

| Parameter | Uitleg |
|---|---|
| `artifactUrl` | Exacte BC-build. Gebruik `Get-BcArtifactUrl` om te zoeken |
| `auth NavUserPassword` | Standaard voor lokale teststraat |
| `includeTestToolkit` | Importeert Test Runner + Library Assert |
| `updateHosts` | Voegt container-naam toe aan `hosts` — vereist voor browsertoegang |
| `licenseFile` | `.bclicense` (BC21+) of `.flf` (BC14-) — vereist voor publiceren |
| `doNotCheckHealth` | Sla health check over; versnelt opstarten maar riskeert gedeeltelijke container |
| `shortcuts = 'None'` | Geen Windows-snelkoppelingen aanmaken op build-agents |

### Container verwijderen en opnieuw maken

```powershell
Remove-BcContainer -containerName "bc-dev"
# Dan opnieuw New-BcContainer
```

---

## .NET assembly deployment

BC-apps die `.NET interop` gebruiken (DotNet variables in AL) vereisen dat de assemblies in de **Add-Ins map van de BC Service Tier** staan. Dit geldt voor de compiler (`alc.exe`) én voor runtime.

### Herkennen of een project .NET assemblies heeft

Zoek naar een `.netpackages/` map in het project:
```bash
find . -name ".netpackages" -type d
```

Als die map bestaat, moeten alle `.dll` bestanden daarin in de container Add-Ins terechtkomen.

### Kopiëren naar container Add-Ins

```powershell
$addInsPath = "C:\Program Files\Microsoft Dynamics NAV\270\Service\Add-ins"
$netPackagesDir = ".\MijnApp\.netpackages"

Get-ChildItem $netPackagesDir -Filter "*.dll" | ForEach-Object {
    Copy-FileToBcContainer -containerName $containerName `
        -localPath $_.FullName `
        -containerPath (Join-Path $addInsPath $_.Name)
}

# Herstart service tier zodat assemblies geladen worden
Restart-BcContainerServiceTier -containerName $containerName
```

### Waarom dit nodig is

`alc.exe` doorzoekt `assemblyprobingpaths` tijdens compilatie. Voor compiler-fouten (`AL0451: assembly not found`) moeten de DLL's ook op de host beschikbaar zijn:
```powershell
# Bij compilatie buiten container (alc.exe direct)
$alcArgs = @(
    "/project:$projectPath",
    "/packagecachepath:$alPackagesPath",
    "/assemblyprobingpaths:$netPackagesPath;C:\Windows\Microsoft.NET\assembly"
)
```

---

## Dependency apps publiceren

Apps die je project afhankelijk van zijn (zie `app.json` → `dependencies`) moeten **vóór** de hoofdapp gepubliceerd worden:

```powershell
# Publiceer dependency (bijv. uit connections/ of dependencyapps/)
Publish-BcContainerApp `
    -containerName $containerName `
    -appFile "connections\Newminds_Agrio Connections_4.0.1.0.app" `
    -skipVerification `
    -sync `
    -install

# Publiceer hoofdapp
Publish-BcContainerApp `
    -containerName $containerName `
    -appFile ".\Aviko_BC Plants_1.0.5.0.app" `
    -skipVerification `
    -sync `
    -install
```

### Publicatievolgorde

1. Basis BC-platform en System Application (al in container)
2. Third-party dependencies (in volgorde van afhankelijkheid)
3. Hoofdapp
4. Test extensie

---

## Test Toolkit

De Test Toolkit bestaat uit vier apps die BcContainerHelper automatisch importeert als je `includeTestToolkit` gebruikt:

| App | AppId | Doel |
|---|---|---|
| Test Runner | `23de40a6-...` | Voert tests uit |
| Library Assert | `dd0be2ea-...` | Assert-functies |
| System Application Test Library | `9856ae4f-...` | Helpers voor System Application |
| Any codeunit | — | Test-codeunits uit je eigen extensie |

### Test extensie bouwen en publiceren

```powershell
# Compileer test extensie (na publicatie van hoofdapp)
$testAppFile = Compile-AppInBcContainer `
    -containerName $containerName `
    -appProjectFolder ".\tests\MijnApp Tests"

# Publiceer zonder install — Run-Tests doet dat automatisch
Publish-BcContainerApp -containerName $containerName `
    -appFile $testAppFile -skipVerification -sync -install
```

### Tests draaien

```powershell
$testCredential = [PSCredential]::new("TESTUSER",
    (ConvertTo-SecureString "Test@1234!" -AsPlainText -Force))

Run-TestsInBcContainer `
    -containerName $containerName `
    -credential $testCredential `
    -XUnitResultFileName ".\results.xunit.xml" `
    -detailed
```

---

## Settings/config patroon

Goed gestructureerde teststraat-projecten scheiden **defaults** van **overrides**:

```
scripts/BcTestHelpers.ps1        ← defaults (container naam, artifact URL, users, ...)
config/teststraat.settings.json  ← overrides (alleen wat afwijkt van defaults)
```

`config/teststraat.settings.json` is de centrale plek voor aanpassingen zonder de scripts te bewerken:

```json
{
  "containerName": "mijnapp-test",
  "mainAppBuildMode": "source",
  "sourceBuildCompatibilityPatches": []
}
```

### Source build vs package build

| Modus | Wanneer | Voordeel |
|---|---|---|
| `package` | Stabiele releases | Snel, geen compilatie nodig |
| `source` | Iteratieve ontwikkeling | Altijd de laatste code |

Source build: de app wordt vanuit broncode gecompileerd vóór publicatie. Compatibiliteitspatches (tijdelijk uitcommentariëren van subscribers, etc.) worden alleen op een staging-kopie toegepast — nooit op de echte broncode.

---

## Container lifecycle

```
New-BcContainer          → container aanmaken (eenmalig of na reset)
    ↓
Setup-Environment        → .NET assemblies, users, dependency apps, hoofdapp
    ↓
Run-Tests (iteratief)    → testextensie compileren + tests draaien
    ↓
Setup-Environment        → alleen als hoofdapp gewijzigd is
    ↓
Remove-BcContainer       → opruimen na sprint / reset
```

### Container hergebruiken vs. opnieuw aanmaken

| Scenario | Aanpak |
|---|---|
| Dagelijkse testcyclus | Container hergebruiken — Setup-Environment indien nodig |
| App.json versie gewijzigd | Opnieuw publiceren via Setup-Environment |
| BC runtime gewijzigd | Container verwijderen en opnieuw aanmaken |
| Licentie verlopen | Nieuwe licentie + container opnieuw aanmaken |
| "Stale" container met rare errors | Recreate — verwijder en begin opnieuw |

---

## Veelvoorkomende fouten

| Fout | Oorzaak | Oplossing |
|---|---|---|
| `AL0451: assembly not found` | .NET DLL niet in Add-Ins | Kopieer naar Add-Ins, herstart service tier |
| `AL1022: package not found` | `.alpackages` leeg | `Download-Symbols.ps1` of `Get-BcArtifactUrl` |
| `Dependency app not found` | Volgorde fout | Publiceer dependency vóór hoofdapp |
| `The tenant ... is not mounted` | Container nog niet ready | Wacht op service tier; verhoog timeout |
| `License is not valid` | Verlopen of verkeerde licentie | Controleer expiratiedatum in licentiebestand |
| `windows containers required` | Docker in Linux mode | `DockerCli.exe -SwitchWindowsEngine` |
