---
name: bc-env
description: Inspect BC environment - installed apps, versions, compare environments via NavAdminTool
bc-version: ">=14.0"
allowed-tools: Bash, Read, Write, Glob
---

# BC Environment

Inspecteer een BC-omgeving: geïnstalleerde apps, versies, status. Gebruikt NavAdminTool via de self-hosted runner.

## Input

$ARGUMENTS — optionele instructies, bijvoorbeeld:
- (leeg) — toon installed extensions op de dev-omgeving
- "pop" of een instance-naam — specifieke omgeving
- "alle" — toon voor alle instances
- "vergelijk dev STE" — vergelijk twee omgevingen
- "eigen" — toon alleen niet-Microsoft apps

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

2. Haal instance-namen op uit CLAUDE.md of `.vscode/launch.json`.

3. Controleer of `bc-runner.yaml` aanwezig is:
   ```bash
   ls .github/workflows/bc-runner.yaml 2>/dev/null && echo "aanwezig" || echo "ontbreekt"
   ```
   Als het ontbreekt: kopieer de template en meld dit.

### Stap 1 — Bepaal omgeving(en)

- Geen argument → dev of eerste instance uit CLAUDE.md
- Instance-naam opgegeven → gebruik die
- "alle" → loop sequentieel over alle instances
- "vergelijk X Y" → vraag beide op en vergelijk

### Stap 2 — Apps opvragen via NavAdminTool

```powershell
$ErrorActionPreference = 'Stop'

Write-Host "=== Apps op $env:BC_INSTANCE ===" -ForegroundColor Cyan

$apps = Get-NAVAppInfo -ServerInstance $env:BC_INSTANCE | Sort-Object Publisher, Name

# Groepeer per publisher
$ownPublisher = "<publisher uit app.json>"  # pas aan
$own    = $apps | Where-Object { $_.Publisher -eq $ownPublisher }
$ms     = $apps | Where-Object { $_.Publisher -eq 'Microsoft' }
$others = $apps | Where-Object { $_.Publisher -ne $ownPublisher -and $_.Publisher -ne 'Microsoft' }

Write-Host ""
Write-Host "--- $ownPublisher (eigen apps) ---"
$own | ForEach-Object {
    Write-Host "  $($_.Name.PadRight(35)) v$($_.Version)  [$($_.Status)]"
}

Write-Host ""
Write-Host "--- Overige publishers ---"
$others | ForEach-Object {
    Write-Host "  $($_.Publisher.PadRight(20)) $($_.Name.PadRight(30)) v$($_.Version)"
}

Write-Host ""
Write-Host "--- Microsoft ($($ms.Count) apps) ---"
$ms | Select-Object -First 5 | ForEach-Object {
    Write-Host "  $($_.Name.PadRight(35)) v$($_.Version)"
}
if ($ms.Count -gt 5) { Write-Host "  ... en $($ms.Count - 5) meer" }

Write-Host ""
Write-Host "Totaal: $($apps.Count) apps ($($own.Count) eigen, $($others.Count) overig, $($ms.Count) Microsoft)"
```

### Stap 3 — Vergelijking (bij "vergelijk X Y")

```powershell
$ErrorActionPreference = 'Stop'

# Dit script wordt twee keer getriggerd (één per instance).
# Combineer de resultaten na ophalen.

$apps = Get-NAVAppInfo -ServerInstance $env:BC_INSTANCE |
    Where-Object Publisher -ne 'Microsoft' |
    Select-Object Name, Publisher, Version, Status, AppId

$apps | ForEach-Object {
    Write-Host "APP|$($_.Name)|$($_.Publisher)|$($_.Version)|$($_.Status)"
}
```

Na het ophalen van beide instances: vergelijk op naam, toon versieverschillen:

```
## Vergelijking: dev vs STE

| App               | dev       | STE       | Verschil       |
|-------------------|-----------|-----------|----------------|
| BC Plants         | 1.0.5.2   | 1.0.5.0   | dev is nieuwer |
| Agrio Connections | 4.0.1.20  | 4.0.1.20  | gelijk         |
| Test App          | 1.0.0.0   | —         | alleen dev     |
```

### Stap 4 — Presenteer resultaat

Sorteer: eigen apps bovenaan, dan overige publishers, Microsoft optioneel (standaard ingeklapt tenzij gebruiker het vraagt).

Markeer apps met `Status != Installed` (NeedsUpgrade, Incomplete, etc.) als aandachtspunt.

## Regels

- Gebruik altijd NavAdminTool via `bc-runner.yaml` — nooit REST of curl
- Trigger instances **sequentieel** — nooit parallel
- Microsoft-apps standaard ingeklapt tenzij "alle" of specifiek gevraagd
- Apps met afwijkende status (niet Installed) altijd expliciet markeren
- Gebruik `/bc-version` voor de specifieke use case "welke versie draait waar en welke git tag hoort erbij"
