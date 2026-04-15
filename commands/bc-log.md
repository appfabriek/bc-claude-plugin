---
name: bc-log
description: Unified BC log viewer - combines Windows event log, NavLog files, and job queue errors into one timeline
bc-version: ">=14.0"
allowed-tools: Bash, Read, Write, Glob
---

# BC Log

Gecombineerde logviewer die Windows Event Log, NavLog-bestanden en Job Queue fouten samenvoegt tot één tijdlijn. Gebruik dit voor troubleshooting wanneer je snel wilt zien wat er fout ging op een omgeving.

## Input

$ARGUMENTS — optionele instructies, bijvoorbeeld:
- (leeg) — laatste uur, alle errors, dev-omgeving
- "pop" of een instance-naam — specifieke omgeving
- "laatste 4 uur" of "vandaag" — tijdsperiode
- "warning" — ook warnings opnemen (standaard: alleen errors)
- "jobs" — focus op Job Queue fouten
- "nav" — focus op NavLog-bestanden
- "zoek <tekst>" — filter op specifieke tekst in de log

## Instructies

### Stap 0 — Laad context

1. Lees `bc-runner-patterns.md` uit de knowledge/ map:
   ```bash
   find ~/.claude/plugins/bc-claude-plugin/knowledge \
        ./.claude/plugins/bc-claude-plugin/knowledge \
        ~/.local/share/claude/plugins/bc-claude-plugin/knowledge \
        ~/code/bc-claude-plugin/knowledge \
        -name "bc-runner-patterns.md" 2>/dev/null | head -1
   ```

2. Lees CLAUDE.md voor instance-namen.

3. Controleer of `bc-runner.yaml` aanwezig is.

### Stap 1 — Bepaal scope

| Parameter | Standaard |
|-----------|-----------|
| Omgeving | dev of eerste instance uit CLAUDE.md |
| Tijdperiode | Laatste 60 minuten |
| Niveau | Error (+ Critical) |
| Bronnen | Alle drie (Event Log, NavLog, Job Queue) |

### Stap 2 — Script: alle bronnen combineren

```powershell
$ErrorActionPreference = 'SilentlyContinue'

$since     = (Get-Date).AddMinutes(-60)   # pas aan naar wens
$maxLevel  = 2                             # 1=Critical, 2=Error, 3=Warning
$searchText = ""                           # optioneel filter
$instance  = $env:BC_INSTANCE

$entries = [System.Collections.Generic.List[PSCustomObject]]::new()

# === BRON 1: Windows Event Log (BC provider) ===
Write-Host "--- Event Log ---" -ForegroundColor DarkGray
try {
    $events = Get-WinEvent -ProviderName "MicrosoftDynamicsNavOrBC" -ErrorAction SilentlyContinue |
        Where-Object { $_.TimeCreated -ge $since -and $_.Level -le $maxLevel }

    if ($searchText) { $events = $events | Where-Object { $_.Message -like "*$searchText*" } }

    foreach ($e in $events) {
        $entries.Add([PSCustomObject]@{
            Time    = $e.TimeCreated
            Source  = 'EventLog'
            Level   = $e.LevelDisplayName
            Message = $e.Message.Substring(0, [Math]::Min(400, $e.Message.Length)).Trim()
        })
    }
    Write-Host "  $($events.Count) entries gevonden"
} catch {
    Write-Host "  Event Log niet beschikbaar: $_"
}

# === BRON 2: NavLog bestanden ===
Write-Host "--- NavLog bestanden ---" -ForegroundColor DarkGray
$bcBase = 'C:\Program Files\Microsoft Dynamics 365 Business Central'
$logDirs = Get-ChildItem $bcBase -Directory -ErrorAction SilentlyContinue |
    ForEach-Object {
        Join-Path $_.FullName "Service\Instances\$instance\Logs"
        Join-Path $_.FullName "Service\Logs"
        "C:\ProgramData\Microsoft\Microsoft Dynamics NAV\$($_.Name)\Server\MicrosoftDynamicsNavServer`$$instance\log"
    } |
    Where-Object { Test-Path $_ }

$navlogCount = 0
foreach ($logDir in $logDirs | Select-Object -Unique) {
    $logFiles = Get-ChildItem $logDir -Filter "*.log" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $since } |
        Sort-Object LastWriteTime -Descending

    foreach ($file in $logFiles) {
        $lines = Get-Content $file.FullName -ErrorAction SilentlyContinue |
            Where-Object { $_ -match '\[ERROR\]|\[FATAL\]|\[WARN\]' } |
            Select-Object -Last 100

        foreach ($line in $lines) {
            # Probeer timestamp te parsen
            $ts = $since
            if ($line -match '(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})') {
                try { $ts = [DateTime]::Parse($Matches[1]) } catch {}
            }
            if ($ts -lt $since) { continue }
            if ($searchText -and $line -notlike "*$searchText*") { continue }

            $level = if ($line -match '\[FATAL\]|\[ERROR\]') { 'Error' } else { 'Warning' }
            $entries.Add([PSCustomObject]@{
                Time    = $ts
                Source  = "NavLog:$($file.Name)"
                Level   = $level
                Message = $line.Trim().Substring(0, [Math]::Min(400, $line.Trim().Length))
            })
            $navlogCount++
        }
    }
}
Write-Host "  $navlogCount entries gevonden"

# === BRON 3: Job Queue fouten (SQL) ===
Write-Host "--- Job Queue fouten ---" -ForegroundColor DarkGray
try {
    $cfg    = Get-NAVServerConfiguration -ServerInstance $instance
    $dbSrv  = $cfg.DatabaseServer
    $dbName = $cfg.DatabaseName

    # Job Queue Entry: Status 3 = Error. Veld 5 = "Error Message", veld 10 = "Last Ready State"
    $jqQuery = @"
SELECT TOP 50
    CONVERT(varchar(30), e.[Last Ready State], 120) AS ts,
    e.[Object Type to Run],
    e.[Object ID to Run],
    e.[Error Message]
FROM [$dbName].[dbo].[CRONUS`$Job Queue Entry] e
WHERE e.[Status] = 3
  AND e.[Last Ready State] >= '$($since.ToString("yyyy-MM-dd HH:mm:ss"))'
ORDER BY e.[Last Ready State] DESC
"@
    # Probeer meerdere company-prefix varianten
    $jqRows = Invoke-Sqlcmd -ServerInstance $dbSrv -Database $dbName -Query $jqQuery -ErrorAction SilentlyContinue

    if (-not $jqRows) {
        # Dynamisch company-prefix zoeken
        $tables = Invoke-Sqlcmd -ServerInstance $dbSrv -Database $dbName `
            -Query "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME LIKE '%Job Queue Entry'" `
            -ErrorAction SilentlyContinue
        if ($tables) {
            $tableName = $tables[0].TABLE_NAME
            $jqQuery2 = $jqQuery -replace "\[CRONUS`\$Job Queue Entry\]", "[$tableName]"
            $jqRows = Invoke-Sqlcmd -ServerInstance $dbSrv -Database $dbName -Query $jqQuery2 -ErrorAction SilentlyContinue
        }
    }

    foreach ($row in $jqRows) {
        if ($searchText -and $row.'Error Message' -notlike "*$searchText*") { continue }
        $ts = try { [DateTime]::Parse($row.ts) } catch { $since }
        $entries.Add([PSCustomObject]@{
            Time    = $ts
            Source  = 'JobQueue'
            Level   = 'Error'
            Message = "Object $($row.'Object Type to Run') $($row.'Object ID to Run'): $($row.'Error Message'.Substring(0, [Math]::Min(300, $row.'Error Message'.Length)))"
        })
    }
    Write-Host "  $(($jqRows | Measure-Object).Count) fouten gevonden"
} catch {
    Write-Host "  Job Queue query mislukt: $_"
}

# === SAMENGEVOEGDE TIJDLIJN ===
Write-Host ""
Write-Host "=== LOG TIJDLIJN: $instance (sinds $($since.ToString('HH:mm'))) ===" -ForegroundColor Cyan
Write-Host "Totaal: $($entries.Count) entries"
Write-Host ""

$entries | Sort-Object Time -Descending | Select-Object -First 50 | ForEach-Object {
    $color = if ($_.Level -eq 'Error' -or $_.Level -eq 'Critical') { 'Red' } else { 'Yellow' }
    Write-Host "[$($_.Time.ToString('HH:mm:ss'))] [$($_.Source.PadRight(12))] $($_.Message)" -ForegroundColor $color
}

if ($entries.Count -gt 50) {
    Write-Host ""
    Write-Host "... ($($entries.Count - 50) meer entries niet getoond — verklein het tijdvenster)"
}
```

### Stap 3 — Presenteer en interpreteer

Geef na de ruwe output een korte samenvatting:

```
## Log samenvatting — pop (laatste 60 min)

| Bron      | Errors | Warnings |
|-----------|--------|----------|
| EventLog  | 3      | 0        |
| NavLog    | 1      | 2        |
| JobQueue  | 2      | 0        |

Meest recente fout: [14:23:01] Job Queue — Codeunit 50018 "SampleReport": ...
```

Als je een patroon ziet (bijv. dezelfde fout herhaaldelijk, of fouten vlak na een deploy), benoem dit expliciet. Stel een vervolgstap voor: `/diagnose` als je de BC-applicatielaag wilt inspecteren.

### Stap 4 — NavLog bestanden locatie vinden (fallback)

Als de standaard logpaden niet werken:

```powershell
# Zoek alle .log bestanden van de afgelopen 2 uur
Get-ChildItem 'C:\ProgramData\Microsoft' -Filter "*.log" -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-2) } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 10 FullName, LastWriteTime, Length
```

## Regels

- Gebruik altijd NavAdminTool via `bc-runner.yaml` — nooit REST API
- Beperk resultaten altijd (standaard: laatste uur, max 50 entries) — logs kunnen enorm zijn
- Job Queue query: probeer dynamisch de tabel te vinden (company-prefix verschilt per installatie)
- Als één bron faalt, ga door met de rest en meld welke bron ontbrak
- Stel `/diagnose` voor als vervolgstap bij applicatie-laag fouten
