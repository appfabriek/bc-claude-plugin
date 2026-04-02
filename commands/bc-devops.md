---
name: bc-devops
description: Generate or update GitHub Actions CI/CD workflow for AL projects
bc-version: ">=18.0"
allowed-tools: Bash, Read, Write, Glob
---

# BC DevOps

Genereer of update een GitHub Actions CI/CD workflow voor een AL-project.

## Input

$ARGUMENTS — modus:
- "--init" of (leeg) — genereer complete workflow
- "--update" — pas bestaande workflow aan op basis van huidige launch.json

## Instructies

### Stap 0 — Laad kennis

1. Lees `bc-devops-patterns.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin -name "bc-devops-patterns.md" 2>/dev/null || find ~/code/bc-claude-plugin/knowledge -name "bc-devops-patterns.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   voor workflow templates, signing, environment matrix.
2. Lees `bc-powershell.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin -name "bc-powershell.md" 2>/dev/null || find ~/code/bc-claude-plugin/knowledge -name "bc-powershell.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   voor BcContainerHelper cmdlets.
3. Lees `app.json` → `name`, `version`, `platform`, `target`.
4. Lees `.vscode/launch.json` → server configuraties.

### Modus: --init

1. Maak `.github/workflows/` aan als die niet bestaat
2. Genereer workflow YAML:

**Keuzes voor de gebruiker:**
- Runner: `ubuntu-latest` (sneller, goedkoper) of `windows-latest` (BcContainerHelper)
- Signing: ja/nee
- Deploy targets: dev, test, productie
- Tests: ja/nee

**Workflow structuur:**
```yaml
name: CI/CD
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build:
    # compile + analyzers
  test:
    needs: build
    # run AL tests
  deploy-dev:
    needs: test
    if: github.ref == 'refs/heads/develop'
    # publish naar dev
  deploy-prod:
    needs: test
    if: github.ref == 'refs/heads/main'
    # publish naar productie (met approval)
```

3. Genereer secrets-lijst die de gebruiker moet instellen

### Modus: --update

1. Lees bestaande workflow YAML
2. Vergelijk met huidige `launch.json` configuraties
3. Voeg ontbrekende deploy-targets toe
4. Update BC versie/artifact URL als nodig

### Output

- Workflow YAML bestand
- Lijst van benodigde GitHub secrets
- Instructie voor het instellen van secrets

## Regels

- Gebruik ALTIJD artifact caching voor .alpackages
- Gebruik ALTIJD `--exit-status` bij `gh run watch`
- ForceSync alleen voor dev, Synchronize voor productie
- Signing verplicht voor productie-deployments
- Lees `bc-devops-patterns.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin -name "bc-devops-patterns.md" 2>/dev/null || find ~/code/bc-claude-plugin/knowledge -name "bc-devops-patterns.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   voor alle templates
