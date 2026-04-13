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

## Vereisten (handmatig, éénmalig)

Vóór het eerste gebruik moet het volgende aanwezig zijn:

| Vereiste | Locatie | Opmerking |
|---|---|---|
| BC27 Developer licentie | `license/BC27_DEV_NL_*.bclicense` | Aanwezig in de repo |
| Agrio Connections app | `connections/Newminds_Agrio Connections_4.0.1.0.app` | Aanwezig in de repo |
| Winget | ingebouwd in Windows 11 | Vereist voor automatische installatie |
| Administrator-rechten | — | Nodig voor `InstallPrereqs.ps1` |

> **Let op**: Na het inschakelen van Hyper-V / Windows Containers (stap 1) is een herstart van Windows vereist. Docker Desktop moet daarna handmatig gestart worden vóór stap 2.

## Instructies

### Stap 0 — Oriënteer jezelf

1. Bepaal de repo-root: zoek `scripts/Initialize-BcPlantsTestLane.ps1` of `scripts/BcPlantsTestHelpers.ps1`.
2. Lees `config/teststraat.settings.json` → actieve overrides (container naam, build mode, patches).
3. Lees `docs/teststraat.md` voor aanvullende projectspecifieke context.

### Stap 1 — Controleer en installeer vereisten

**Voer uit als Administrator:**

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/InstallPrereqs.ps1
```

Dit installeert/verifieert:
- PowerShell 7 (`pwsh`) via winget
- GitHub CLI (`gh`) via winget
- Docker Desktop via winget
- Windows-features: `Microsoft-Hyper-V-All`, `Containers`
- BcContainerHelper PowerShell-module
- Schakelt Docker Desktop naar Windows-container mode

**Verwacht resultaat:** `>>> Prerequisite script completed.`

**Als het script meldt dat Windows opnieuw gestart moet worden:**
> Stop. Herstart Windows. Start Docker Desktop handmatig. Ga dan verder met stap 2.

**Controleer Docker handmatig:**
```powershell
docker version --format "{{.Server.Os}}"
# Verwacht: windows
```

Als Docker niet draait: start Docker Desktop en wacht tot het systeem-icoon stabiel is.

### Stap 2 — Maak of hergebruik de BC container

**Normale setup** (hergebruikt bestaande container als die al bestaat):
```powershell
pwsh -NoLogo -NoProfile -File scripts/New-BcPlantsTestContainer.ps1
```

**Reset** (verwijder bestaande container en maak nieuw):
```powershell
pwsh -NoLogo -NoProfile -File scripts/New-BcPlantsTestContainer.ps1 -Recreate
```

Dit doet:
1. Valideert Docker in Windows-container mode
2. Controleert het licentiebestand in `license/`
3. Maakt container `bcplants-test` aan op BC 27.3 (artifact URL uit `BcPlantsTestHelpers.ps1`)
4. Importeert automatisch de Test Toolkit

**Verwacht resultaat:** `[container] Container 'bcplants-test' is running`

**Fout: licentiebestand niet gevonden**
```
throw "License file not found: ..."
```
→ Controleer of `license/BC27_DEV_NL_*.bclicense` aanwezig is. Dit bestand zit in de repo.

**Fout: artifact download mislukt**
```
Exception calling "DownloadFile" ...
```
→ Controleer internetverbinding. De BC artifact URL is hardcoded in `BcPlantsTestHelpers.ps1`. Controleer of de URL nog geldig is:
```powershell
. scripts/BcPlantsTestHelpers.ps1
(Get-BcPlantsDefaultSettings).artifactUrl
```

### Stap 3 — Bootstrap de testomgeving

```powershell
pwsh -NoLogo -NoProfile -File scripts/Setup-BcPlantsTestEnvironment.ps1
```

Dit doet:
1. Wacht tot BC-service `running` is (timeout: 6 min)
2. Maakt testgebruiker `AUTORUN2` aan met SUPER-rechten
3. **Kopieert .NET assemblies** uit `BC Plants/.netpackages/` naar Add-Ins in de container
4. Publiceert `Agrio Connections` dependency
5. Bouwt BC Plants uit source (`mainAppBuildMode = source`) en publiceert het
6. Schrijft setup-log naar `.artifacts/test-results/setup/<timestamp>-setup.json`

**Verwacht resultaat:** setup-log aangemaakt, geen errors.

**Fout: `.NET assembly` niet gevonden in Add-Ins**
De assemblies (`MySql.Data.dll`, `NM_2_0_0_3.dll`, etc.) moeten in de container Add-Ins folder terechtkomen. Als de setup-stap hier faalt:
```powershell
# Controleer of netpackages aanwezig zijn
ls "BC Plants/.netpackages/"
# Verwacht: MySql.Data.dll, NM_2_0_0_3.dll, Signature.dll, nmSocket.dll, ...
```

**Fout: subscriber `OnGetWorkFloorResponse` niet gevonden**
Dit is een bekende compatibiliteitspatch. Controleer `config/teststraat.settings.json`:
```json
{
  "sourceBuildCompatibilityPatches": [
    "DisableMissingAgrCrtOnGetWorkFloorResponseSubscriber"
  ]
}
```
Als de patch er niet in staat, voeg hem toe.

### Stap 4 — Draai de tests

```powershell
pwsh -NoLogo -NoProfile -File scripts/Run-BcPlantsTests.ps1
```

Dit doet:
1. Refresht de hoofdapp in de container (source-mode: herbouwen + herpubliceren)
2. Compileert de testextensie uit `tests/BC Plants Tests`
3. Draait alle tests via `Run-TestsInBcContainer`
4. Schrijft resultaten naar `.artifacts/test-results/<timestamp>/`

**Verwacht resultaat:**
```
Results: X passed, 0 failed
Summary: .artifacts/test-results/<timestamp>/summary.md
```

**Bekijk de samenvatting:**
```powershell
$latest = Get-ChildItem .artifacts/test-results -Directory | Sort-Object Name | Select-Object -Last 1
cat "$($latest.FullName)/summary.md"
```

### One-shot bootstrap (alles in één commando)

Wanneer alles klopt en geen reset nodig is:
```powershell
pwsh -NoLogo -NoProfile -File scripts/Initialize-BcPlantsTestLane.ps1 -RunTests
```

Met reset van de container:
```powershell
pwsh -NoLogo -NoProfile -File scripts/Initialize-BcPlantsTestLane.ps1 -RecreateContainer -RunTests
```

## Dagelijkse werkcyclus

Na de initiële setup is de werkcyclus:

```
code schrijven / test aanpassen
↓
pwsh scripts/Run-BcPlantsTests.ps1
↓
.artifacts/test-results/<timestamp>/summary.md lezen
↓
herhalen
```

Als alleen de hoofdapp ververst moet worden zonder tests:
```powershell
pwsh scripts/Setup-BcPlantsTestEnvironment.ps1
```

## Configuratie aanpassen

`config/teststraat.settings.json` bevat overrides op de defaults in `scripts/BcPlantsTestHelpers.ps1`.

| Instelling | Default | Uitleg |
|---|---|---|
| `containerName` | `bcplants-test` | Docker container naam |
| `mainAppBuildMode` | `package` | `source` of `package` |
| `sourceBuildCompatibilityPatches` | `[]` | Patches voor source-build |
| `dependencyAppFile` | `connections/...` | Pad naar Agrio Connections |
| `testUser` | `AUTORUN2` | Testgebruiker in de container |

## Problemen

| Symptoom | Oorzaak | Oplossing |
|---|---|---|
| `docker: command not found` | Docker Desktop niet gestart | Start Docker Desktop |
| `windows containers required` | Docker staat in Linux mode | `& 'C:\Program Files\Docker\Docker\DockerCli.exe' -SwitchWindowsEngine` |
| `License file not found` | Licentie ontbreekt | Controleer `license/` map |
| `AL1022: package not found` | `.alpackages` niet gevuld | `pwsh scripts/Download-Symbols.ps1` |
| `AL0451: assembly not found` | .NET DLL's niet in Add-Ins | Herrun `Setup-BcPlantsTestEnvironment.ps1` |
| Tests compileren niet | Versie-mismatch testextensie | Herrun `Run-BcPlantsTests.ps1` (herstelt automatisch) |
| Container bestaand, settings gewijzigd | Stale container | `New-BcPlantsTestContainer.ps1 -Recreate` |

## Regels

- Draai `InstallPrereqs.ps1` altijd als Administrator
- Herstart Windows wanneer het script dat aangeeft — sla dit niet over
- Start Docker Desktop handmatig na elke herstart
- Gebruik `config/teststraat.settings.json` voor overrides — bewerk `BcPlantsTestHelpers.ps1` nooit direct
- De `sourceBuildCompatibilityPatches` worden ALLEEN op de staging-kopie toegepast — nooit op de echte broncode
