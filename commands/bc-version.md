---
name: bc-version
description: Show which version of the main app is running on each BC environment, and correlate with git tags for debugging
bc-version: ">=14.0"
allowed-tools: Bash, Read, Write, Glob
---

# BC Version

Toon welke versie van de app op elke omgeving draait, gecorreleerd met git tags. Gebruik dit om snel te zien welke codebase overeenkomt met welke omgeving — essentieel voor debugging en release-tracking.

## Input

$ARGUMENTS — optionele instructies, bijvoorbeeld:
- (leeg) — toon versie op alle instances, correleer met git tags
- "pop" of een instance-naam — toon versie op die specifieke omgeving
- "checkout pop" — stel de git worktree in op de versie die op pop draait
- "vergelijk" — markeer duidelijk welke omgeving achterloopt

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

2. Lees `app.json` → `name` en `version` (huidige werkversie in de codebase).

3. Haal alle BC instances op uit CLAUDE.md of `.vscode/launch.json`.

4. Controleer of `bc-runner.yaml` aanwezig is:
   ```bash
   ls .github/workflows/bc-runner.yaml 2>/dev/null && echo "aanwezig" || echo "ontbreekt"
   ```

5. Haal beschikbare git tags op:
   ```bash
   git tag -l --sort=-version:refname | head -20
   ```

### Stap 1 — Versie opvragen per omgeving

Trigger `bc-runner.yaml` per instance. Gebruik de `name` uit `app.json` als filter.

```powershell
$ErrorActionPreference = 'Stop'
$appName = "<naam uit app.json>"

$app = Get-NAVAppInfo -ServerInstance $env:BC_INSTANCE |
    Where-Object { $_.Name -eq $appName } |
    Sort-Object Version -Descending |
    Select-Object -First 1

if ($app) {
    Write-Host "version=$($app.Version)"
    Write-Host "status=$($app.Status)"
    Write-Host "publisher=$($app.Publisher)"
    Write-Host "app_id=$($app.AppId)"
} else {
    Write-Host "version=not_installed"
    Write-Host "status=NotFound"
}
```

Trigger **sequentieel** per instance en verzamel de output.

### Stap 2 — Git tag correlatie

Voor elke gevonden versie (bijv. `1.0.4.8`):

```bash
# Zoek exacte tag
git tag -l "v1.0.4.8" "1.0.4.8" "*1.0.4.8*" 2>/dev/null

# Of zoek in git log op versienummer in commit message
git log --oneline --all | grep "1.0.4.8" | head -3
```

Als een tag gevonden wordt: noteer de overeenkomst. Als niet: vermeld dat er geen tag is voor die versie.

### Stap 3 — Overzicht presenteren

```
## App versies: BC Plants

| Omgeving  | Versie    | Status    | Git tag    | Achterstand |
|-----------|-----------|-----------|------------|-------------|
| dev       | 1.0.5.2   | Installed | v1.0.5.2   | ← huidig    |
| STE       | 1.0.5.0   | Installed | v1.0.5.0   | 2 versies   |
| STA       | 1.0.4.12  | Installed | v1.0.4.12  | 4 versies   |
| pop       | 1.0.4.8   | Installed | v1.0.4.8   | 8 versies   |
| rai       | 1.0.4.8   | Installed | v1.0.4.8   | 8 versies   |

Codebase (app.json): 1.0.5.2
```

Markeer:
- Omgevingen met een andere versie dan de huidige codebase
- Omgevingen op dezelfde versie (klaar voor deploy)
- Omgevingen zonder overeenkomende git tag (risico: codebase kan afwijken)

### Stap 4 — Git checkout suggestie (bij debuggen)

Als de gebruiker een specifieke omgeving wil debuggen:

```bash
# Checkout de exacte tag voor die omgeving
git checkout v1.0.4.8

# Of maak een detached HEAD voor inspectie zonder worktree te vervuilen:
git checkout --detach v1.0.4.8

# Terug naar huidig werk:
git checkout -
```

Waarschuw bij `git checkout` als er uncommitted changes zijn (`git status`). Stel `git stash` voor als dat het geval is.

## Regels

- Gebruik altijd NavAdminTool via `bc-runner.yaml` — nooit REST API
- Trigger instances **sequentieel**, nooit parallel
- Als er geen `bc-runner.yaml` is: meld dit en verwijs naar de setup instructies
- Toon altijd de versie in `app.json` naast de omgevingsversies — dat is de referentie
- Als een versie geen git tag heeft: vermeld dit expliciet (versie is niet traceerbaar)
