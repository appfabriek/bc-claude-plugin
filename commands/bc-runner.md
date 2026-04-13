---
name: bc-runner
description: Execute NavAdminTool cmdlets or PowerShell remotely on a BC OnPrem server via GitHub Actions self-hosted runner
bc-version: ">=14.0"
allowed-tools: Bash, Read, Write, Glob
---

# BC Runner

Voer PowerShell uit op de remote BC-server via de self-hosted GitHub Actions runner. Gebruik dit voor alles wat NavAdminTool, BcContainerHelper of directe server-toegang vereist.

**Wanneer `/bc-runner` i.p.v. `/diagnose`:**
- `/diagnose` → AL code uitvoeren (tabellen, codeunits, business logic)
- `/bc-runner` → NavAdminTool, server admin, app deployment, SQL, gebruikersbeheer, licenties

## Input

$ARGUMENTS — beschrijving van wat je wilt doen. Voorbeelden:
- "welke versie van BC Plants draait op elke omgeving"
- "herstart de dev instance"
- "hoeveel gebruikers zijn actief op pop"
- "check of licentie bijna verloopt"
- "deploy versie 1.0.5 naar alle accept-omgevingen"
- "toon event log errors van de afgelopen 24 uur op STE"
- "controleer server configuratie van alle instances"

## Instructies

### Stap 0 — Laad kennis

1. Lees `bc-runner-patterns.md` uit de knowledge/ map van de bc-claude-plugin.
   ```bash
   find ~/.claude/plugins/bc-claude-plugin/knowledge \
        ./.claude/plugins/bc-claude-plugin/knowledge \
        ~/.local/share/claude/plugins/bc-claude-plugin/knowledge \
        ~/code/bc-claude-plugin/knowledge \
        -name "bc-runner-patterns.md" 2>/dev/null | head -1
   ```
   Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.

2. Lees CLAUDE.md voor:
   - Beschikbare BC instances en hun instance-namen (pop, rai, STA, STE, dev)
   - ForceSync-omgevingen (destructief — nooit zonder expliciete bevestiging)
   - Repo-locatie en build-output paden

3. Controleer of `bc-runner.yaml` aanwezig is:
   ```bash
   ls .github/workflows/bc-runner.yaml 2>/dev/null && echo "aanwezig" || echo "ontbreekt"
   ```
   Als het ontbreekt: kopieer de template en meld dit aan de gebruiker (zie Stap 1b).

### Stap 1 — Analyseer de vraag

Bepaal:
- **Welke omgeving(en)**: één instance, meerdere sequentieel, of alle
- **Type actie**:
  - `query` — alleen lezen, geen bijwerkingen (safe)
  - `deploy` — app publiceren/installeren (onomkeerbaar per versie)
  - `admin` — server config, restart, gebruikersbeheer (risicovol)
  - `destructive` — uninstall, ForceSync, schema-wijziging (bevestiging vereist)

**Vraag bevestiging** voor `admin` en `destructive` acties tenzij de gebruiker al expliciet akkoord gaf.

### Stap 1b — Workflow setup (indien ontbreekt)

Als `bc-runner.yaml` nog niet aanwezig is:

```bash
# Kopieer template
cp $(find ~/.claude/plugins/bc-claude-plugin/templates \
     ~/code/bc-claude-plugin/templates \
     -name "bc-runner.yaml" 2>/dev/null | head -1) \
   .github/workflows/bc-runner.yaml
```

Vervolgens: pas de `environment` opties en `$envMap` in het YAML aan op basis van de instances in CLAUDE.md of `.vscode/launch.json`. Commit voor gebruik.

### Stap 2 — Schrijf het PowerShell script

Schrijf een PowerShell script dat:
- `$env:BC_INSTANCE` gebruikt voor de instance naam (wordt door de workflow gezet)
- `$env:REPO_ROOT` gebruikt voor repo-paden
- `$env:BC_BASE_PATH` gebruikt voor de BC installatiemap
- Gestructureerde output schrijft (`Write-Host` met herkenbare labels)
- `$ErrorActionPreference = 'Stop'` gebruikt

**NavAdminTool is al geladen** — gebruik cmdlets direct zonder import.

Raadpleeg `bc-runner-patterns.md` voor kant-en-klare code snippets per use case.

### Stap 3 — Trigger de workflow

```bash
cat > /tmp/bc-runner.ps1 << 'PSEOF'
# Jouw PowerShell script hier
PSEOF

gh workflow run bc-runner.yaml \
  -f environment="<omgeving uit de yaml options>" \
  -f description="<korte omschrijving>" \
  -F script=@/tmp/bc-runner.ps1
```

**Meerdere omgevingen**: trigger **sequentieel** (wacht op elke run voordat de volgende start). De self-hosted runner kan maar 1 job tegelijk draaien.

### Stap 4 — Wacht op resultaat

```bash
sleep 3
RUN_ID=$(gh run list --workflow=bc-runner.yaml --limit=1 --json databaseId -q '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status

# Lees output van de "Execute script" stap
gh run view "$RUN_ID" --log 2>&1 | grep -A 300 "Execute script"
```

### Stap 5 — Parseer en rapporteer

Interpreteer de output en geef een duidelijk antwoord. Bij meerdere omgevingen: combineer de resultaten in één overzicht.

### Stap 6 — Itereer indien nodig

Als de eerste run onvoldoende info geeft, verfijn het script en trigger opnieuw.

---

## Recepten per use case

### App versies op alle omgevingen

```powershell
$ErrorActionPreference = 'Stop'

Write-Host "=== App versies op $env:BC_INSTANCE ===" -ForegroundColor Cyan

Get-NAVAppInfo -ServerInstance $env:BC_INSTANCE |
  Where-Object { $_.Publisher -ne 'Microsoft' } |
  Sort-Object Publisher, Name |
  ForEach-Object {
    $status = if ($_.Status -eq 'Installed') { 'OK' } else { $_.Status }
    Write-Host "  $($_.Publisher) | $($_.Name) | v$($_.Version) | $status"
  }
```

Trigger per omgeving en combineer de output in een vergelijkingstabel.

### Server health overzicht

```powershell
$ErrorActionPreference = 'Stop'

$instances = Get-NAVServerInstance
Write-Host "=== BC Server Health: $($instances.Count) instances ===" -ForegroundColor Cyan

foreach ($inst in $instances) {
  $cfg = Get-NAVServerConfiguration -ServerInstance $inst.ServerInstance -ErrorAction SilentlyContinue
  $appCount = (Get-NAVAppInfo -ServerInstance $inst.ServerInstance -ErrorAction SilentlyContinue | Measure-Object).Count
  $nonMsApps = (Get-NAVAppInfo -ServerInstance $inst.ServerInstance -ErrorAction SilentlyContinue |
    Where-Object Publisher -ne 'Microsoft' | Measure-Object).Count

  Write-Host ""
  Write-Host "Instance: $($inst.ServerInstance) [$($inst.State)]"
  Write-Host "  DB:   $($cfg.DatabaseServer)\$($cfg.DatabaseName)"
  Write-Host "  Apps: $appCount totaal, $nonMsApps eigen"
}
```

### Licentie check

```powershell
$lic = Get-NAVServerLicense -ServerInstance $env:BC_INSTANCE
$daysLeft = ($lic.ExpirationDate - (Get-Date)).Days

Write-Host "Licentie op $env:BC_INSTANCE"
Write-Host "  Partner:    $($lic.PartnerName)"
Write-Host "  Customer:   $($lic.CustomerName)"
Write-Host "  Verloopt:   $($lic.ExpirationDate.ToString('yyyy-MM-dd')) ($daysLeft dagen)"
Write-Host "  Type:       $($lic.LicenseType)"

if ($daysLeft -lt 30) {
  Write-Host "  STATUS: VERLOOPT BINNENKORT!" -ForegroundColor Red
} elseif ($daysLeft -lt 90) {
  Write-Host "  STATUS: Verloopt over $daysLeft dagen" -ForegroundColor Yellow
} else {
  Write-Host "  STATUS: OK" -ForegroundColor Green
}
```

### Event log errors (laatste 24u)

```powershell
$since = (Get-Date).AddHours(-24)

$events = Get-WinEvent -ProviderName "MicrosoftDynamicsNavOrBC" -ErrorAction SilentlyContinue |
  Where-Object { $_.TimeCreated -gt $since -and $_.Level -le 2 } |
  Select-Object -First 20

Write-Host "=== BC Event Log fouten (laatste 24u) op $env:BC_INSTANCE ==="
Write-Host "Gevonden: $($events.Count)"
foreach ($e in $events) {
  Write-Host ""
  Write-Host "[$($e.TimeCreated.ToString('HH:mm:ss'))] $($e.LevelDisplayName)"
  Write-Host "  $($e.Message.Substring(0, [Math]::Min(300, $e.Message.Length)))"
}
```

### Gebruikers overzicht

```powershell
$users = Get-NAVServerUser -ServerInstance $env:BC_INSTANCE -Tenant default
Write-Host "=== Gebruikers op $env:BC_INSTANCE ($($users.Count) totaal) ==="
$users | Sort-Object State, UserName |
  ForEach-Object {
    Write-Host "  [$($_.State)] $($_.UserName) — $($_.FullName) ($($_.LicenseType))"
  }
```

### App deployen

```powershell
param(
  [string]$AppPath = "",
  [string]$AppName = "",
  [string]$AppVersion = "",
  [string]$SyncMode = "Synchronize"  # of ForceSync
)

# Gebruik REPO_ROOT als geen pad opgegeven
if (-not $AppPath) {
  $AppPath = Get-ChildItem $env:REPO_ROOT -Filter "*.app" |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
}
$info = Get-NAVAppInfo -Path $AppPath
$AppName = $info.Name
$AppVersion = $info.Version.ToString()

Write-Host "=== Deploy $AppName v$AppVersion naar $env:BC_INSTANCE ==="

Publish-NAVApp -ServerInstance $env:BC_INSTANCE -Path $AppPath -Scope Global -SkipVerification
Write-Host "  Published"

Sync-NAVApp -ServerInstance $env:BC_INSTANCE -Name $AppName -Version $AppVersion -Tenant default -Mode $SyncMode
Write-Host "  Synced ($SyncMode)"

try {
  Start-NAVAppDataUpgrade -ServerInstance $env:BC_INSTANCE -Name $AppName -Version $AppVersion -Tenant default
  Write-Host "  Data upgrade OK"
} catch {
  Install-NAVApp -ServerInstance $env:BC_INSTANCE -Name $AppName -Version $AppVersion -Tenant default
  Write-Host "  Installed"
}

Write-Host "=== Klaar ==="
```

---

## Regels

- **Query-acties**: altijd veilig om direct uit te voeren
- **Deploy-acties**: bevestig versie en doelomgeving vóór uitvoering
- **Admin/destructief**: vraag expliciete bevestiging — herstel is soms onmogelijk
- **ForceSync**: alleen op omgevingen die dit expliciet toestaan per CLAUDE.md
- **Sequentieel**: nooit meerdere runner-jobs parallel triggeren
- Gebruik `bc-diagnostic.yaml` (via `/diagnose`) als je AL-code nodig hebt; gebruik `bc-runner.yaml` voor alles wat PowerShell is
- Sla herbruikbare scripts op in memory als ze succesvol waren
