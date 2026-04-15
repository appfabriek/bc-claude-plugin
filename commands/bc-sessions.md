---
name: bc-sessions
description: Inspect and manage active BC user sessions - who is logged in, which company, stuck sessions
bc-version: ">=14.0"
allowed-tools: Bash, Read, Write, Glob
---

# BC Sessions

Bekijk actieve gebruikerssessies op een BC-omgeving en verwijder vastgelopen sessies via de self-hosted runner.

## Input

$ARGUMENTS — optionele instructies, bijvoorbeeld:
- (leeg) — toon alle actieve sessies op de dev-omgeving
- "pop" of een omgevingsnaam — toon sessies op die specifieke omgeving
- "alle" — toon sessies per instance op alle instances
- "stuck" — toon alleen sessies die langer dan X minuten actief zijn
- "verwijder sessie 42" of "kill [gebruikersnaam]" — verwijder een specifieke sessie

## Wanneer

- Gebruiker meldt dat een record geblokkeerd is ("iemand heeft dit open")
- Performanceproblemen of te veel actieve sessies
- Integratie-service vastgelopen (sessie cleanen zonder service restart)
- Periodieke health check ("wie is er ingelogd op productie?")

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

2. Controleer of `bc-runner.yaml` aanwezig is:
   ```bash
   ls .github/workflows/bc-runner.yaml 2>/dev/null && echo "aanwezig" || echo "ontbreekt"
   ```

3. Lees CLAUDE.md voor de beschikbare instance-namen.

### Stap 1 — Bepaal scope

- Geen argument → gebruik de dev/eerste instance uit CLAUDE.md
- Omgevingsnaam opgegeven → gebruik die instance
- "alle" → loop over alle instances sequentieel
- "stuck [N minuten]" → filter sessies ouder dan N minuten (standaard: 60)
- "verwijder"/"kill" → identificeer de sessie eerst, vraag bevestiging, verwijder daarna

**Vraag altijd bevestiging voor `Remove-NAVServerSession`** — een verwijderde sessie verliest niet-opgeslagen werk van de gebruiker.

### Stap 2 — Sessies opvragen

```powershell
$ErrorActionPreference = 'Stop'

$sessions = Get-NAVServerSession -ServerInstance $env:BC_INSTANCE

Write-Host "=== Actieve sessies op $env:BC_INSTANCE ($($sessions.Count) totaal) ===" -ForegroundColor Cyan
Write-Host ""

$sessions | Sort-Object LoginTime | ForEach-Object {
    $duration = [Math]::Round(((Get-Date) - $_.LoginTime).TotalMinutes)
    $durationStr = if ($duration -lt 60) { "${duration}m" } else { "$([Math]::Floor($duration/60))u $($duration % 60)m" }

    Write-Host "[$($_.SessionId)] $($_.UserId)"
    Write-Host "  Company:    $($_.CurrentCompany)"
    Write-Host "  Client:     $($_.ClientType)"
    Write-Host "  Ingelogd:   $($_.LoginTime.ToString('HH:mm:ss')) ($durationStr geleden)"
    if ($_.ApplicationAreaCode) {
        Write-Host "  App area:   $($_.ApplicationAreaCode)"
    }
    Write-Host ""
}

# Samenvatting per clienttype
$byType = $sessions | Group-Object ClientType | Sort-Object Count -Descending
Write-Host "--- Per clienttype ---"
$byType | ForEach-Object { Write-Host "  $($_.Name): $($_.Count)" }
```

### Stap 2b — Stuck sessies filteren

```powershell
$minMinutes = 60  # aanpassen naar wens
$cutoff = (Get-Date).AddMinutes(-$minMinutes)

$stuck = Get-NAVServerSession -ServerInstance $env:BC_INSTANCE |
    Where-Object { $_.LoginTime -lt $cutoff }

Write-Host "Sessies ouder dan $minMinutes minuten: $($stuck.Count)"
$stuck | Sort-Object LoginTime | ForEach-Object {
    $mins = [Math]::Round(((Get-Date) - $_.LoginTime).TotalMinutes)
    Write-Host "  [$($_.SessionId)] $($_.UserId) — $mins min — $($_.ClientType) — $($_.CurrentCompany)"
}
```

### Stap 3 — Sessie verwijderen (met bevestiging)

**Vraag eerst bevestiging aan de gebruiker met:**
- Sessie-ID
- Gebruikersnaam
- Clienttype
- Inlogtijd / duur
- Waarschuwing: niet-opgeslagen werk gaat verloren

Na bevestiging:

```powershell
$sessionId = <ID>  # het te verwijderen sessie-ID

$session = Get-NAVServerSession -ServerInstance $env:BC_INSTANCE |
    Where-Object SessionId -eq $sessionId

if (-not $session) {
    Write-Host "Sessie $sessionId niet gevonden (mogelijk al verlopen)" -ForegroundColor Yellow
    exit 0
}

Write-Host "Verwijder sessie $sessionId van $($session.UserId) ($($session.ClientType))..."
Remove-NAVServerSession -ServerInstance $env:BC_INSTANCE -SessionId $sessionId
Write-Host "Sessie verwijderd." -ForegroundColor Green
```

### Stap 4 — Resultaat presenteren

Geef een overzicht als tabel:

```
## Sessies op dev (5 actief)

| ID | Gebruiker          | Company       | Clienttype  | Duur   |
|----|--------------------|---------------|-------------|--------|
| 12 | DOMAIN\mike        | AVIKO BE      | WebClient   | 2u 14m |
| 15 | DOMAIN\geert       | AVIKO NL      | WebClient   | 23m    |
| 18 | SVC_INTEGRATION    | AVIKO BE      | ODataV4     | 4u 01m |  ← mogelijk stuck
| 21 | DOMAIN\test        | AVIKO NL      | WebClient   | 8m     |
| 24 | SVC_SCHEDULER      | AVIKO NL      | Background  | 12m    |
```

Markeer service-accounts of sessies ouder dan 2u als aandachtspunt.

## Regels

- Vraag ALTIJD bevestiging voor `Remove-NAVServerSession`
- Noem de gebruiker, duur en clienttype expliciet in de bevestigingsvraag
- Service-accounts (integraties, scheduler) kunnen langlopende sessies hebben — dat is normaal
- Background-sessies zijn meestal job queue workers — verwijder die alleen als ze echt stuck zijn
- Bij "alle" omgevingen: nooit parallel triggeren; sequentieel per instance
