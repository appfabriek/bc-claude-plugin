---
name: bc-data-upgrade
description: Manage BC data upgrade lifecycle - start, monitor, resume, or stop tenant data upgrades
bc-version: ">=14.0"
allowed-tools: Bash, Read, Write, Glob
---

# BC Data Upgrade

Beheer de data upgrade lifecycle op een BC OnPrem tenant via de self-hosted runner. Gebruik dit bij app-updates die schema-wijzigingen bevatten, bij gefailde upgrades die hervat moeten worden, of om de upgrade-status te controleren.

## Input

$ARGUMENTS — optionele instructies, bijvoorbeeld:
- (leeg) of "status" — toon de huidige upgrade-status op de dev-omgeving
- "status alle" — toon upgrade-status op alle instances
- "start [omgeving]" — start een data upgrade op de opgegeven omgeving
- "resume [omgeving]" — hervat een onderbroken upgrade
- "stop [omgeving]" — stop een lopende upgrade (kan later hervat worden)
- "check [omgeving]" — controleer of er apps staan te wachten op upgrade

## Wanneer gebruiken

- Na een app-deploy waarbij `Start-NAVAppDataUpgrade` faalde
- Tenant staat in `UpgradePending` of `NeedsDataUpgrade` status
- Opvolging na een versie-update: zijn alle tenants bijgewerkt?
- Grote upgrade waarbij de voortgang gevolgd moet worden

## Instructies

### Stap 0 — Laad kennis en controleer workflow

1. Lees `bc-runner-patterns.md` uit de knowledge/ map van de bc-claude-plugin.
   ```bash
   find ~/.claude/plugins/bc-claude-plugin/knowledge \
        ./.claude/plugins/bc-claude-plugin/knowledge \
        ~/.local/share/claude/plugins/bc-claude-plugin/knowledge \
        ~/code/bc-claude-plugin/knowledge \
        -name "bc-runner-patterns.md" 2>/dev/null | head -1
   ```

2. Controleer of `bc-runner.yaml` aanwezig is. Lees CLAUDE.md voor instance-namen.

### Stap 1 — Bepaal actie

| Argument | Actie |
|----------|-------|
| leeg / "status" | `Get-NAVDataUpgrade` — toon status |
| "check" | `Get-NAVAppInfo` — apps met status NeedsUpgrade |
| "start" | `Start-NAVDataUpgrade` — start de upgrade |
| "resume" | `Resume-NAVDataUpgrade` — hervat na storing |
| "stop" | `Stop-NAVDataUpgrade` — pauzeer (niet annuleren) |

**Vraag bevestiging** voor start/resume/stop — dit raakt lopende productiedata.

### Stap 2 — Scripts per actie

#### Status opvragen

```powershell
$ErrorActionPreference = 'Stop'

# Apps die wachten op data upgrade
Write-Host "=== Apps die data upgrade nodig hebben op $env:BC_INSTANCE ===" -ForegroundColor Cyan
$pendingApps = Get-NAVAppInfo -ServerInstance $env:BC_INSTANCE -Tenant default |
    Where-Object { $_.NeedsDataUpgrade -or $_.Status -eq 'NeedsUpgrade' }

if ($pendingApps.Count -eq 0) {
    Write-Host "  Geen apps wachten op data upgrade." -ForegroundColor Green
} else {
    $pendingApps | ForEach-Object {
        Write-Host "  $($_.Name) v$($_.Version) — Status: $($_.Status)"
    }
}

# Actieve of laatste data upgrade
Write-Host ""
Write-Host "=== Upgrade geschiedenis ===" -ForegroundColor Cyan
try {
    $upgrade = Get-NAVDataUpgrade -ServerInstance $env:BC_INSTANCE -Tenant default -ErrorAction SilentlyContinue
    if ($upgrade) {
        $upgrade | ForEach-Object {
            Write-Host "  App:     $($_.ExtensionName) v$($_.ExtensionVersion)"
            Write-Host "  Status:  $($_.Status)"
            Write-Host "  Gestart: $($_.StartedDateTime)"
            if ($_.CompletedDateTime) {
                Write-Host "  Klaar:   $($_.CompletedDateTime)"
            }
            if ($_.Error) {
                Write-Host "  Fout:    $($_.Error)" -ForegroundColor Red
            }
            Write-Host ""
        }
    } else {
        Write-Host "  Geen upgrade-geschiedenis gevonden."
    }
} catch {
    Write-Host "  Kan upgrade-status niet ophalen: $_" -ForegroundColor Yellow
}
```

#### Data upgrade starten

```powershell
$ErrorActionPreference = 'Stop'

# Controleer welke apps klaar zijn voor upgrade
$readyApps = Get-NAVAppInfo -ServerInstance $env:BC_INSTANCE -Tenant default |
    Where-Object { $_.NeedsDataUpgrade -eq $true -or $_.Status -eq 'NeedsUpgrade' }

if ($readyApps.Count -eq 0) {
    Write-Host "Geen apps hoeven een data upgrade." -ForegroundColor Green
    exit 0
}

Write-Host "Apps die geüpgraded worden:"
$readyApps | ForEach-Object { Write-Host "  $($_.Name) v$($_.Version)" }
Write-Host ""

foreach ($app in $readyApps) {
    Write-Host "Starten data upgrade: $($app.Name) v$($app.Version)..." -ForegroundColor Cyan
    try {
        Start-NAVAppDataUpgrade -ServerInstance $env:BC_INSTANCE `
            -Name $app.Name -Version $app.Version -Tenant default
        Write-Host "  OK" -ForegroundColor Green
    } catch {
        Write-Host "  FOUT: $_" -ForegroundColor Red
        Write-Host "  Gebruik 'resume' om verder te gaan na correctie."
    }
}
```

#### Upgrade hervatten

```powershell
$ErrorActionPreference = 'Stop'

Write-Host "=== Herstarten data upgrade op $env:BC_INSTANCE ===" -ForegroundColor Cyan

try {
    Resume-NAVDataUpgrade -ServerInstance $env:BC_INSTANCE -Tenant default
    Write-Host "  Upgrade hervat." -ForegroundColor Green
} catch {
    Write-Host "  Fout bij hervatten: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Controleer de upgrade-status:"
    Get-NAVDataUpgrade -ServerInstance $env:BC_INSTANCE -Tenant default -ErrorAction SilentlyContinue |
        ForEach-Object {
            Write-Host "  $($_.ExtensionName): $($_.Status)"
            if ($_.Error) { Write-Host "  Fout: $($_.Error)" -ForegroundColor Red }
        }
}
```

#### Upgrade stoppen (pauzeren)

```powershell
$ErrorActionPreference = 'Stop'

Write-Host "=== Stoppen data upgrade op $env:BC_INSTANCE ===" -ForegroundColor Yellow
Write-Host "De upgrade wordt gepauzeerd en kan later hervat worden met 'resume'."
Write-Host ""

Stop-NAVDataUpgrade -ServerInstance $env:BC_INSTANCE -Tenant default
Write-Host "Upgrade gestopt." -ForegroundColor Yellow

# Toon huidige status
Get-NAVDataUpgrade -ServerInstance $env:BC_INSTANCE -Tenant default -ErrorAction SilentlyContinue |
    ForEach-Object {
        Write-Host "  $($_.ExtensionName) v$($_.ExtensionVersion): $($_.Status)"
    }
```

### Stap 3 — Rapporteer

Presenteer het resultaat als een duidelijk statusoverzicht:

```
## Data upgrade status — dev

| App              | Versie    | Status          | Gestart   | Fout |
|------------------|-----------|-----------------|-----------|------|
| BC Plants        | 1.0.5.0   | Completed       | 14:23:01  | —    |
| Agrio Connections| 4.0.1.20  | NeedsUpgrade    | —         | —    |
```

Bij fouten: toon de foutmelding en suggereer de volgende stap (resume / herinstallatie / CLAUDE.md raadplegen voor bekende valkuilen).

## Upgrade volgorde

Bij meerdere apps met dependencies: upgrade in dependency-volgorde (basisapp eerst, extensies daarna). Gebruik het patroon uit `bc-runner-patterns.md` (`Get-AppPublishOrder`) om de volgorde te bepalen.

## Regels

- Vraag bevestiging voor start/resume/stop op productie-omgevingen
- Stop nooit een data upgrade halverwege tenzij noodzakelijk — de tenant blijft in een inconsistente staat tot hervatten
- Bij een fout in de upgrade: lees de foutmelding volledig voordat je `Resume` aanroept — los de oorzaak eerst op
- ForceSync is soms nodig vóór een data upgrade bij destructieve schema-wijzigingen — check CLAUDE.md voor welke omgevingen dit toegestaan is
- Gebruik `/diagnose` als je de foutmelding in de BC-applicatielaag wilt zien (bijv. een gefailde upgrade-codeunit)
