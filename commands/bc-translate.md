---
name: bc-translate
description: Sync translations across all XLF language files
bc-version: ">=14.0"
allowed-tools: Bash, Read, Write, mcp__nab-al-tools
---

# BC Translate

Synchroniseer vertalingen na wijzigingen in AL-code: units toevoegen/bijwerken met **NAB AL Tools' eigen code**,
vertalingen ter akkoord voorleggen, opslaan via de NAB MCP-server en aantonen dat geen bestaande vertaling omviel.

**Nooit** trans-units zelf in XLF-bestanden schrijven (geen regex/eigen scripts). NAB doet de plaatsing, states,
exact-match en hint-notes; handwerk wijkt daar ongemerkt van af.

## Input

$ARGUMENTS — optionele instructies, bijvoorbeeld:
- (leeg) — synchroniseer en vertaal alles wat nieuw of gewijzigd is
- "check" — alleen rapporteren (wat ontbreekt / te reviewen), niets wijzigen
- `nl="tekst"` of `"Engelse bron"=>"NL tekst"` — bekende vertaling meegeven (gaat vóór eigen voorstel; geldt voor nl-NL en nl-BE)

```
/bc-translate "Sent to SCADA planning"=>"Naar SCADA planning verzonden" "Updates processed"=>"Updates verwerkt"
```

## Instructies

### Stap 0 — Projectcontext

1. Lees `al-guidelines.md` uit de knowledge/ map van de bc-claude-plugin:
   `find ~/.claude/plugins/bc-claude-plugin/knowledge ./.claude/plugins/bc-claude-plugin/knowledge ~/.local/share/claude/plugins/bc-claude-plugin/knowledge ~/code/bc-claude-plugin/knowledge -name "al-guidelines.md" 2>/dev/null | head -1`
2. Zoek het AL-project (map met `app.json`), lees `name`, en controleer `"features": ["TranslationFile"]` — zo niet: meld en stop.
3. Zoek de workspace-file (`*.code-workspace` in repo-root) — NAB-settings zoals `NAB.UseTargetStates` staan daar.
4. Lees de projectinstructies (AGENTS.md / CLAUDE.md / docs over vertalingen). **Heeft het project eigen
   vertaalscripts, gebruik die** — bijv. `scripts/refresh-xlf.sh`, `scripts/gxlf-mac.sh`, `scripts/Test-XlfRegression.ps1`.

### Stap 1 — Verse g.xlf

De g.xlf moet uit de huidige broncode komen (anders mis je units of zie je verouderde bronnen).
- Project-script aanwezig (bijv. `gxlf-mac.sh`): draai dat.
- Anders: bouw het project (`AL: Package` / alc). Op macOS lukt dat vaak niet door .NET-interop-errors — zie de
  macOS-sectie in `al-guidelines.md`; bouw dan een scratch-kopie waarin alleen de interop-types/-aanroepen zijn
  geneutraliseerd (die bevatten geen vertaalbare teksten), en raak de echte broncode niet aan.

### Stap 2 — Units synchroniseren met NAB (niet zelf)

- Project-script (bijv. `refresh-xlf.sh`): draai dat (`--check-only` bij "check").
- Anders de officiële NAB-refresh als CLI uit de VS Code-extensie:
  ```bash
  NAB_CLI=$(ls -d ~/.vscode/extensions/nabsolutions.nab-al-tools-*/dist/cli/RefreshXLF.js | sort -V | tail -1)
  node "$NAB_CLI" "<app-folder>" "<workspace>.code-workspace"            # wijzigt
  node "$NAB_CLI" "<app-folder>" "<workspace>.code-workspace" --check-only  # alleen rapport
  ```
- **Niet** de MCP-tool `refreshXlf` van het npm-pakket `@nabsolutions/nab-al-tools-mcp` 1.43: die kent
  `NAB.UseTargetStates` niet en stript alle `state="translated"`.

Bij "check": rapporteer de NAB-tellingen per taal en stop.

### Stap 3 — Wat moet vertaald worden

Via de NAB MCP-server (zie Stap 5 voor de juiste server): `initialize` (met `appFolderPath` en `workspaceFilePath`),
daarna per taalbestand `getTextsToTranslate` (en `getTranslatedTextsByState` voor `needs-review-translation`).
Zonder MCP: zoek in de taal-XLF's naar `state="needs-translation"`, `needs-review-translation`, `needs-adaptation`.

Let op bij **gewijzigde bron**: BC kiest een vertaling op trans-unit-ID, dus tot de unit opnieuw vertaald is ziet
de gebruiker de oude vertaling bij de nieuwe bron. Deze units horen er altijd bij.

### Stap 4 — Voorstel ter akkoord

Bouw een tabel per unit: bron (EN) · waar (object/control) · NL · DE · FR (nl-BE = nl-NL, fr-BE = fr-FR tenzij
het project anders wil). Gebruik eerst bekende vertalingen:
- uit $ARGUMENTS (gaat voor alles);
- uit de git diff: een hardcoded NL-string die door een Label met Engelse source is vervangen
  (`- Message('Naar SCADA planning verzonden')` → `+ TextSCADA: Label 'Sent to SCADA planning'`);
- bestaande vertalingen van dezelfde/vergelijkbare bron in de taalbestanden (consistentie);
- `getGlossaryTerms` voor BC-standaardtermen.
Behoud placeholders (`%1`, `%2%3`) exact. Meld waar je afwijkt van een bestaand patroon.

**Wacht op akkoord** — sla niets op zonder expliciete goedkeuring van de gebruiker.

### Stap 5 — Opslaan via NAB MCP

`saveTranslatedTexts` per taalbestand (batch), na `initialize`. Controleer eerst welke server draait:
- Goed: de server uit de VS Code-extensie (`…/nabsolutions.nab-al-tools-<versie>/dist/mcp/server.js`, ≥ 1.48) — zet
  `state="translated"` correct.
- Fout: npm `nab-al-tools-mcp` 1.43 (geen `initialize`-tool, wel `workspaceFilePath` per tool) — zet géén state.
  Laat de gebruiker de MCP omzetten (wrapper die de extensie-server start; zie de projectdocs) i.p.v. om te werken.

### Stap 6 — Bewijs dat niets omviel

- Project-script (bijv. `Test-XlfRegression.ps1 -GXlfPath <g.xlf>`): draai het; exit 0 vereist.
- Anders: `git diff` per taalbestand — alleen `<source>`/`<target>`/NAB-notes van de bedoelde units mogen wijzigen;
  geen verwijderde units, geen andere targets, geen `state="translated"` die verdwijnt. Plus `RefreshXLF.js --check-only`.
- Backport naar een release-branch: toets het **merge-resultaat** met die branch, niet de PR-branch zelf
  (als de release-branch verder ging, geeft een directe vergelijking vals alarm).
- Bouw de app (of de scratch-kopie) zodat de XLF's in de `.app` meegaan.

### Stap 7 — Rapporteer

Per taal: aantal units toegevoegd / bron gewijzigd / vertaald, resterende `needs-*`-tellingen van NAB, en de
uitkomst van de regressiecontrole.

## Regels

- Nooit zelf trans-units invoegen of XLF's met regex bewerken — altijd NAB (CLI-refresh + MCP `saveTranslatedTexts`).
- Nooit een bestaande vertaling overschrijven zonder dat de bron wijzigde, tenzij de gebruiker die hervertaling vraagt.
- Vertalingen altijd eerst ter akkoord voorleggen.
- Alle taalbestanden meenemen, niet één.
- Labels met `Locked = true` staan niet in de XLF — correct, niet melden.
