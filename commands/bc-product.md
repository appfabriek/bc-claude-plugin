---
name: bc-product
description: ISV product workflow - spec, roadmap, changelog
bc-version: ">=14.0"
allowed-tools: Read, Write
---

# BC Product

ISV-product workflow: genereer functionele spec, roadmap, of changelog.

## Input

$ARGUMENTS — modus:
- "--spec" — genereer functionele specificatie
- "--roadmap" — analyseer TODO/FIXME en maak sprint-suggesties
- "--changelog" — genereer CHANGELOG.md uit git log

## Instructies

### Stap 0 — Laad kennis

1. Lees `app.json` → `name`, `version`, `description`, `publisher`.
2. Lees `al-guidelines.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin -name "al-guidelines.md" 2>/dev/null || find ~/code/bc-claude-plugin/knowledge -name "al-guidelines.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   voor object-structuur context.
3. Lees `bc-appsource.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin -name "bc-appsource.md" 2>/dev/null || find ~/code/bc-claude-plugin/knowledge -name "bc-appsource.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   voor submission requirements (indien ISV).

### Modus: --spec

1. Scan alle AL-objecten in het project
2. Groepeer per functioneel domein (op basis van mapstructuur of object prefix)
3. Genereer voor elk domein:
   - Tabellen met belangrijkste velden
   - Pages (welke lijsten, kaarten, FactBoxen)
   - Codeunits (welke business logic)
   - Integraties (API pages, events)
4. Format als Markdown document met:
   - Inhoudsopgave
   - Per domein: doel, objecten, dataflow
   - Afhankelijkheden (andere apps)

### Modus: --roadmap

1. Scan alle AL-bestanden voor:
   ```bash
   grep -rn "TODO\|FIXME\|HACK\|XXX\|REFACTOR" --include="*.al" .
   ```
2. Categoriseer per prioriteit:
   - **Bug:** FIXME, HACK
   - **Feature:** TODO met beschrijving
   - **Tech debt:** REFACTOR, XXX
3. Groepeer per domein/bestand
4. Suggereer sprint-indeling op basis van afhankelijkheden en complexiteit

### Modus: --changelog

1. Lees `app.json` → huidige versie
2. Zoek de vorige versie-tag in git:
   ```bash
   git tag --sort=-v:refname | head -5
   ```
3. Genereer changelog uit commits sinds vorige tag:
   ```bash
   git log <vorige-tag>..HEAD --oneline --no-merges
   ```
4. Groepeer per type (feat, fix, refactor, chore):
   ```markdown
   # Changelog

   ## [2.1.0] - 2026-04-02

   ### Nieuwe features
   - Beschrijving van feat commits

   ### Bugfixes
   - Beschrijving van fix commits

   ### Verbeteringen
   - Beschrijving van refactor/chore commits
   ```

## Regels

- Spec: focus op functioneel (wat doet het), niet technisch (hoe werkt het)
- Roadmap: wees realistisch, niet alles hoeft in één sprint
- Changelog: schrijf vanuit gebruikersperspectief, niet technisch
- Gebruik `app.json` versie als referentie
