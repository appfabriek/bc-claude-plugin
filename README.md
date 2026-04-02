# bc-claude-plugin

Claude Code plugin met skills en een ingebouwde knowledge base voor BC AL-ontwikkeling.

## Skills

| Commando | Doel |
|----------|------|
| `/dev-publish` | Compileer en publiceer AL-app naar BC dev server |
| `/diagnose` | Voer remote AL-diagnostics uit via GitHub Actions |
| `/bc-translate` | Synchroniseer vertalingen in alle XLF-taalbestanden |
| `/bc-review` | Review AL-code tegen Microsoft-richtlijnen |
| `/bc-query` | Stel datavragen in gewoon Nederlands aan een BC-omgeving |
| `/bc-env` | Inspecteer een BC-omgeving: geinstalleerde apps, versies |

## Knowledge base

De plugin bevat een ingebouwde kennisbank zodat Claude direct productief is in elk BC-project:

| Bestand | Inhoud |
|---------|--------|
| `knowledge/al-guidelines.md` | Microsoft AL-naamgeving, patronen, performance, events, upgrades |
| `knowledge/bc-tables.md` | Standaard BC-tabellen met veldnummers en optie-waarden |
| `knowledge/diagnostic-recipes.md` | Bewezen AL-snippets voor veelvoorkomende diagnostic queries |

Skills lezen deze bestanden automatisch — geen extra setup nodig.

---

## Installatie

### Vereisten

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (CLI of VS Code extensie)
- GitHub CLI (`gh`) — nodig voor `/diagnose` en `/bc-query`
- VS Code met [AL Language extensie](https://marketplace.visualstudio.com/items?itemName=ms-dynamics-smb.al) — nodig voor `/dev-publish`

### Installeren vanuit GitHub

```
/install-plugin github:appfabriek/bc-claude-plugin
```

Dit installeert alle skills en de knowledge base in een keer.

### Installeren vanuit een lokale map

```
/install-plugin /pad/naar/bc-claude-plugin
```

### Verwijderen

```
/uninstall-plugin bc-claude-plugin
```

---

## Gebruik

### In Claude Code (CLI)

Start Claude Code in je AL-projectmap en gebruik de skills:

```bash
# In je AL-project directory
claude

# Compileer en publiceer
> /dev-publish

# Publiceer met Synchronize (niet-destructief)
> /dev-publish synchronize

# Remote diagnostic
> /diagnose hoeveel open orders zijn er op dev

# Datavraag in gewoon Nederlands
> /bc-query top 10 klanten op saldo, omgeving productie

# Code review
> /bc-review

# Vertalingen synchroniseren
> /bc-translate

# Omgeving inspecteren
> /bc-env
```

### In VS Code (Claude Code extensie)

1. Installeer de [Claude Code extensie](https://marketplace.visualstudio.com/items?itemName=anthropic.claude-code) in VS Code
2. Open het Claude Code panel (Cmd+Shift+P → "Claude Code: Open")
3. Gebruik dezelfde skill-commando's als hierboven

---

## Setup voor je team

### Stap 1 — Plugin installeren

Elk teamlid voert eenmalig uit in Claude Code:

```
/install-plugin github:appfabriek/bc-claude-plugin
```

### Stap 2 — .NET Framework reference assemblies (macOS)

De AL compiler op macOS heeft .NET Framework 4.7.2 reference DLLs nodig. Deze zitten **niet** in de AL extensie zelf.

**Optie A — NuGet (aanbevolen, ~42MB):**
```bash
DEST=~/code/bc-claude-plugin/netframework-ref
mkdir -p "$DEST"
nuget install Microsoft.NETFramework.ReferenceAssemblies.net472 -OutputDirectory /tmp/netref
cp -r /tmp/netref/Microsoft.NETFramework.ReferenceAssemblies.net472.*/build/.NETFramework/v4.7.2 "$DEST/"
```

**Optie B — Kopieer van een collega:**
```bash
cp -r "<collega>/v4.7.2" ~/code/bc-claude-plugin/netframework-ref/v4.7.2
```

### Stap 3 — AL project configureren

Voeg de reference assemblies toe aan `.vscode/settings.json` van elk AL-project:

```json
{
    "al.assemblyProbingPaths": [
        "/Users/JOUW_NAAM/code/bc-claude-plugin/netframework-ref/v4.7.2",
        "/Users/JOUW_NAAM/code/bc-claude-plugin/netframework-ref/v4.7.2/Facades"
    ]
}
```

### Stap 4 — Credentials instellen

Voeg BC server credentials toe aan de `CLAUDE.md` van je AL-project:

```markdown
## BC Credentials
- Username: admin
- Password: [wachtwoord]
```

Of sla ze op in Claude's memory (dan hoeven ze niet in een bestand).

### Stap 5 — Symbols downloaden

Open je AL-project in VS Code en draai **AL: Download Symbols** (Ctrl+Shift+P). Dit vult de `.alpackages/` map met de benodigde platform symbols. Zonder symbols kan `/dev-publish` niet compileren.

---

## Hoe werken de skills?

### `/dev-publish`
1. Leest `app.json`, `launch.json`, `settings.json` uit je project
2. Zoekt de AL compiler (`alc`) in je VS Code extensies
3. Compileert het project
4. Publiceert de `.app` via het BC Dev Services REST endpoint
5. Verifieert dat de app actief is

### `/diagnose`
1. Schrijft AL diagnostic code op basis van je vraag
2. Triggert een GitHub Actions workflow die de code uitvoert op de BC-omgeving
3. Leest het resultaat uit de workflow logs
4. Presenteert het antwoord

### `/bc-query`
Zelfde mechanisme als `/diagnose`, maar je stelt de vraag in gewoon Nederlands. Claude schrijft de AL-code en presenteert het resultaat zonder technisch jargon.

### `/bc-translate`
1. Scant gewijzigde AL-bestanden (git diff) voor nieuwe Caption/ToolTip/Label
2. Leest het master XLF-bestand (`.g.xlf`)
3. Voegt ontbrekende trans-units toe aan alle taalbestanden (nl-NL, nl-BE, fr-FR, fr-BE, de-DE)

### `/bc-review`
1. Leest de AL-richtlijnen uit de knowledge base
2. Scant je code op naamgeving, performance, foutafhandeling en architectuur
3. Rapporteert bevindingen per categorie met regelnummers en aanbevelingen

### `/bc-env`
1. Leest `launch.json` voor server-informatie
2. Haalt geinstalleerde extensies op via de BC API
3. Toont een overzicht gesorteerd op publisher

---

## Bijdragen

Skills zijn Markdown-bestanden in `commands/`. Knowledge files staan in `knowledge/`. Wijzig het relevante bestand en test door de plugin lokaal te herinstalleren:

```
/install-plugin /pad/naar/bc-claude-plugin
```

---

## Waarom .NET Framework 4.7.2 en niet .NET Core?

.NET Core splitst types over tientallen aparte assemblies. Zodra je een .NET Core DLL laadt, breekt de resolutie van andere types (bijv. `WebClient` verliest `Headers`/`UploadValues`). Met de 4.7.2 reference assemblies werkt alles gewoon.
