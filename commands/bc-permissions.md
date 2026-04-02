---
name: bc-permissions
description: Generate or audit permission sets for AL projects
bc-version: ">=18.0"
allowed-tools: Bash, Read, Write, Glob
---

# BC Permissions

Genereer of audit permission sets voor een AL-project.

## Input

$ARGUMENTS — modus:
- "--generate" of (leeg) — genereer permission sets op basis van gebruikte objecten
- "--audit" — vergelijk permission sets met objecten in het project

## Instructies

### Stap 0 — Laad kennis

1. Lees `bc-permissions.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin/knowledge ./.claude/plugins/bc-claude-plugin/knowledge ~/.local/share/claude/plugins/bc-claude-plugin/knowledge ~/code/bc-claude-plugin/knowledge -name "bc-permissions.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   voor syntax, entitlements, audit checklist.
2. Lees `al-guidelines.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin/knowledge ./.claude/plugins/bc-claude-plugin/knowledge ~/.local/share/claude/plugins/bc-claude-plugin/knowledge ~/code/bc-claude-plugin/knowledge -name "al-guidelines.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   voor naamgeving.
3. Lees `app.json` → `name`, `idRanges`, prefix.

### Modus: --generate

1. Scan alle AL-objecten in het project
2. Categoriseer per type:
   - Tabellen → `tabledata` permissions (R/I/M/D)
   - Pages → `page` permissions (X)
   - Codeunits → `codeunit` permissions (X)
   - Reports → `report` permissions (X)
   - Queries → `query` permissions (X)
3. Genereer twee permission sets:
   - **Admin** — RIMD op alle tabellen, X op alle objecten
   - **Basic User** — RIMD op document-tabellen, R op setup, X op relevante pages
4. Als er base-tabellen worden gebruikt (via table extensions):
   - Voeg indirect permissions toe (lowercase: `rim`)
5. Genereer entitlement objects als `app.json` target = Cloud

### Modus: --audit

1. Lees alle bestaande `.PermissionSet.al` bestanden
2. Scan alle objecten in het project
3. Rapporteer:
   - Objecten zonder permission entry
   - Permission entries voor niet-bestaande objecten
   - Setup-tabellen met te brede rechten (RIMD in plaats van R)
   - Ontbrekende entitlement objects

## Regels

- Assignable name: max 20 tekens
- Prefix met app-naam
- Base-tabel permissions: indirect (lowercase)
- Setup-tabellen: R voor users, RIMD voor admins
- Lees `bc-permissions.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin/knowledge ./.claude/plugins/bc-claude-plugin/knowledge ~/.local/share/claude/plugins/bc-claude-plugin/knowledge ~/code/bc-claude-plugin/knowledge -name "bc-permissions.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   voor alle details
