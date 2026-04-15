# bc-claude-plugin

Claude Code plugin met 27 skills en een ingebouwde knowledge base voor BC AL-ontwikkeling. Maakt Claude tot een BC-expert die direct productief is in elk AL-project.

---

## Installatie

### Via de plugin marketplace (aanbevolen)

In een Claude Code sessie:

```
/plugin marketplace add appfabriek/bc-claude-plugin
/plugin install bc-claude-plugin@bc-claude-plugin
```

### Lokaal installeren

```bash
git clone https://github.com/appfabriek/bc-claude-plugin.git ~/code/bc-claude-plugin
```

In een Claude Code sessie:

```
/plugin install /pad/naar/bc-claude-plugin
```

### Verwijderen

```
/plugin uninstall bc-claude-plugin
```

### Vereisten

- Claude Code v1.0.33 of hoger (controleer: `claude --version`)
- GitHub CLI (`gh`) — vereist voor `/diagnose`, `/bc-runner` en `/bc-query`
- VS Code met [AL Language extensie](https://marketplace.visualstudio.com/items?itemName=ms-dynamics-smb.al) — vereist voor `/dev-publish`

### Setup voor /diagnose, /bc-runner en /bc-query

Deze commands vereisen GitHub Actions workflows in je AL-project. Kopieer de workflow templates:

```bash
# Voor AL-code diagnostics (al uitvoeren, data opvragen)
cp ~/code/bc-claude-plugin/templates/bc-diagnostic.yaml \
   /pad/naar/jouw-al-project/.github/workflows/bc-diagnostic.yaml

# Voor NavAdminTool/PowerShell op de BC-server (app-beheer, server admin, SQL)
cp ~/code/bc-claude-plugin/templates/bc-runner.yaml \
   /pad/naar/jouw-al-project/.github/workflows/bc-runner.yaml
```

**Vereisten voor OnPrem self-hosted runners:**
- Self-hosted runner op de BC-server met labels `self-hosted, Windows, X64, <hostnaam>`
- NavAdminTool beschikbaar (`C:\Program Files\Microsoft Dynamics 365 Business Central\<versie>\Service\NavAdminTool.ps1`)
- Pas de `environment` opties en `$envMap` in de workflows aan op je BC-instances

**Vereisten voor `/bc-env` (SaaS/REST):**
- Stel de volgende GitHub Secrets in als je BC via REST benadert:
  - `BC_URL_DEV`, `BC_USER_DEV`, `BC_PASS_DEV`
  - `BC_URL_TEST`, `BC_USER_TEST`, `BC_PASS_TEST`
  - `BC_URL_ACCEPT`, `BC_USER_ACCEPT`, `BC_PASS_ACCEPT`
  - `BC_URL_PRODUCTION`, `BC_USER_PRODUCTION`, `BC_PASS_PRODUCTION`

---

## Skills (27 commands)

### Workflow

| Commando | Doel |
|----------|------|
| `/bc-issue [nummer]` | Pak een GitHub issue op: branch → code → build → vertaling → PR |

### Lokale Teststraat

| Commando | Doel |
|----------|------|
| `/bc-teststraat [setup\|reset\|run]` | Opzetten of herstellen lokale BC testomgeving |
| `/bc-teststraat-verify` | Diagnoseer de staat van de lokale teststraat |

### Build & Deploy

| Commando | Doel |
|----------|------|
| `/dev-publish` | Compileer en publiceer AL-app naar BC dev server |
| `/bc-ps [taak]` | Genereer BcContainerHelper PowerShell scripts |
| `/bc-devops [--init\|--update]` | Genereer/update GitHub Actions CI/CD workflows |

### Diagnostics & Data

| Commando | Doel |
|----------|------|
| `/diagnose [vraag]` | Remote AL-diagnostics via GitHub Actions (AL-code uitvoeren op server) |
| `/bc-runner [taak]` | NavAdminTool/PowerShell op de BC-server: app-beheer, users, SQL, licentie, event log |
| `/bc-sessions [omgeving]` | Bekijk actieve sessies; verwijder stuck sessies |
| `/bc-data-upgrade [omgeving]` | Data upgrade lifecycle: status, start, hervatten, stoppen |
| `/bc-version [omgeving]` | Welke versie draait waar, gecorreleerd met git tags voor debugging |
| `/bc-log [omgeving]` | Gecombineerde logviewer: event log + NavLog bestanden + job queue fouten |
| `/bc-query [vraag]` | Datavragen in gewoon Nederlands |
| `/bc-env [omgeving]` | Inspecteer BC-omgeving: apps, versies (NavAdminTool) |

### Code Quality

| Commando | Doel |
|----------|------|
| `/bc-review [bestand]` | Review AL-code tegen Microsoft-richtlijnen |
| `/bc-perf [--scan\|--query]` | Scan op performance anti-patterns |
| `/bc-test [codeunit]` | Genereer en voer AL-tests uit |

### Code Generation

| Commando | Doel |
|----------|------|
| `/bc-new <type> [naam]` | Scaffold nieuw AL-object |
| `/bc-api <tabel> [--query]` | Genereer API page of API query |
| `/bc-copilot <naam>` | Scaffold BC Copilot capability (System.AI) |
| `/bc-events [--list\|--subscribe\|--publish]` | BC events zoeken, subscriben, publiceren |
| `/bc-permissions [--generate\|--audit]` | Genereer of audit permission sets |
| `/bc-telemetry [--add\|--review\|--kql]` | Telemetry toevoegen, reviewen, KQL genereren |

### Lifecycle

| Commando | Doel |
|----------|------|
| `/bc-upgrade [--analyze\|--generate]` | Analyseer en genereer upgrade-codeunits |
| `/bc-migrate [--from X --to Y]` | BC versie-migratie assistent |
| `/bc-translate` | Vertalingen synchroniseren in alle XLF-bestanden |
| `/bc-product [--spec\|--roadmap\|--changelog]` | ISV product workflow |

---

## Knowledge Base

De plugin bevat een ingebouwde kennisbank van 21 bestanden zodat Claude direct productief is:

| Categorie | Bestanden |
|-----------|-----------|
| **AL Development** | `al-guidelines.md`, `bc-tables.md`, `bc-events.md`, `bc-static-analysis.md` |
| **Patterns** | `bc-api-patterns.md`, `bc-test-patterns.md`, `bc-copilot-patterns.md`, `bc-telemetry-patterns.md` |
| **Architecture** | `bc-architecture-decisions.md`, `bc-upgrade-patterns.md`, `bc-permissions.md`, `bc-reports.md` |
| **DevOps & Local Dev** | `bc-devops-patterns.md`, `bc-local-dev.md`, `bc-powershell.md`, `bc-debugging.md` |
| **ISV** | `bc-appsource.md`, `bc-version-matrix.md`, `bc-dataverse.md` |
| **Diagnostics & Remote** | `diagnostic-recipes.md`, `bc-runner-patterns.md` |

Skills lezen deze bestanden automatisch — geen extra setup nodig.

---

## Development Workflow

De plugin volgt de [Superpowers workflow](https://github.com/obra/superpowers):

1. **Design before code** — begrijp het probleem, stel oplossingen voor
2. **Plan with exact details** — concrete stappen, geen vage instructies
3. **Compile-verify cycle** — compileer na elke wijziging, verifieer op server
4. **Systematic debugging** — lees foutmeldingen, één hypothese per keer
5. **Evidence over claims** — toon compile output, nooit "het zou moeten werken"

---

## Setup voor je team

### Stap 1 — Plugin installeren

```
/install-plugin github:appfabriek/bc-claude-plugin
```

### Stap 2 — .NET Framework reference assemblies (macOS)

```bash
DEST=~/code/bc-claude-plugin/netframework-ref
mkdir -p "$DEST"
nuget install Microsoft.NETFramework.ReferenceAssemblies.net472 -OutputDirectory /tmp/netref
cp -r /tmp/netref/Microsoft.NETFramework.ReferenceAssemblies.net472.*/build/.NETFramework/v4.7.2 "$DEST/"
```

### Stap 3 — AL project configureren

```json
{
    "al.assemblyProbingPaths": [
        "/Users/JOUW_NAAM/code/bc-claude-plugin/netframework-ref/v4.7.2",
        "/Users/JOUW_NAAM/code/bc-claude-plugin/netframework-ref/v4.7.2/Facades"
    ]
}
```

### Stap 4 — Symbols downloaden

Open je AL-project in VS Code → **AL: Download Symbols** (Ctrl+Shift+P).

---

## Bijdragen

Skills zijn Markdown in `commands/`, knowledge in `knowledge/`. Alle skill files hebben YAML frontmatter. Test door lokaal te herinstalleren:

```
/install-plugin /pad/naar/bc-claude-plugin
```
