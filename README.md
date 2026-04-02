# bc-claude-plugin

Claude Code plugin met 19 skills en een ingebouwde knowledge base voor BC AL-ontwikkeling. Maakt Claude tot een BC-expert die direct productief is in elk AL-project.

---

## Installatie

### Vereisten

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (CLI of VS Code extensie)
- GitHub CLI (`gh`) — nodig voor `/diagnose` en `/bc-query`
- VS Code met [AL Language extensie](https://marketplace.visualstudio.com/items?itemName=ms-dynamics-smb.al) — nodig voor `/dev-publish`

### Installeren

```
/install-plugin github:appfabriek/bc-claude-plugin
```

Dit installeert alle skills en de knowledge base in een keer. Werkt in Claude Code CLI en VS Code extensie.

### Lokaal installeren (ontwikkeling)

```
/install-plugin /pad/naar/bc-claude-plugin
```

---

## Skills (19 commands)

### Build & Deploy

| Commando | Doel |
|----------|------|
| `/dev-publish` | Compileer en publiceer AL-app naar BC dev server |
| `/bc-ps [taak]` | Genereer BcContainerHelper PowerShell scripts |
| `/bc-devops [--init\|--update]` | Genereer/update GitHub Actions CI/CD workflows |

### Diagnostics & Data

| Commando | Doel |
|----------|------|
| `/diagnose [vraag]` | Remote AL-diagnostics via GitHub Actions |
| `/bc-query [vraag]` | Datavragen in gewoon Nederlands |
| `/bc-env [omgeving]` | Inspecteer BC-omgeving: apps, versies, vergelijk |

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

De plugin bevat een ingebouwde kennisbank van 19 bestanden zodat Claude direct productief is:

| Categorie | Bestanden |
|-----------|-----------|
| **AL Development** | `al-guidelines.md`, `bc-tables.md`, `bc-events.md`, `bc-static-analysis.md` |
| **Patterns** | `bc-api-patterns.md`, `bc-test-patterns.md`, `bc-copilot-patterns.md`, `bc-telemetry-patterns.md` |
| **Architecture** | `bc-architecture-decisions.md`, `bc-upgrade-patterns.md`, `bc-permissions.md`, `bc-reports.md` |
| **DevOps** | `bc-devops-patterns.md`, `bc-powershell.md`, `bc-debugging.md` |
| **ISV** | `bc-appsource.md`, `bc-version-matrix.md`, `bc-dataverse.md` |
| **Diagnostics** | `diagnostic-recipes.md` |

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
