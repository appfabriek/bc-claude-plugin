---
name: bc-finsql
description: Import and compile Business Central C/SIDE text objects (OBJECT Codeunit … .txt) with the bundled KMT finsql script. Never invent finsql.exe arguments.
bc-version: ">=14.0"
allowed-tools: Bash, Read, Write, Glob
---

# BC finsql (C/SIDE import/compile)

Importeer of compileer C/SIDE-tekstobjecten (`OBJECT Codeunit …` in een `.txt`) via `finsql.exe` op een BC14 RTC-omgeving (KMT).

**Gebruik altijd het gebundelde script `scripts/kmt-finsql-import.ps1`.** Verzin geen eigen finsql-aanroep, geen komma-string, geen zelfbedachte `Start-Process`. Elke afwijking hiervan heeft in de praktijk gefaald.

## Input

$ARGUMENTS — wat er moet gebeuren, bijvoorbeeld:
- pad naar een C/SIDE `.txt` + object-id (import + compile)
- "compileer codeunit 50062"
- "importeer COD50070 - Native Artist Pages.txt als 50070"

## Instructies

### Stap 0 — Laad kennis

1. Lees `bc-finsql.md` uit de knowledge/ map van de bc-claude-plugin.
   ```bash
   find ~/.claude/plugins/bc-claude-plugin/knowledge \
        ./.claude/plugins/bc-claude-plugin/knowledge \
        ~/.local/share/claude/plugins/bc-claude-plugin/knowledge \
        ~/code/bc-claude-plugin/knowledge \
        -name "bc-finsql.md" 2>/dev/null | head -1
   ```
   Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.

2. Zoek het script:
   ```bash
   find ~/.claude/plugins/bc-claude-plugin/scripts \
        ./.claude/plugins/bc-claude-plugin/scripts \
        ~/.local/share/claude/plugins/bc-claude-plugin/scripts \
        ~/code/bc-claude-plugin/scripts \
        -name "kmt-finsql-import.ps1" 2>/dev/null | head -1
   ```
   Kopieer het naar `C:\NAVServices\CRT\kmt-finsql-import.ps1` op de BC-server als het daar nog niet staat. Voer het op die Windows-host uit (via `/bc-runner` als de job daar draait).

### Stap 1 — Bepaal de actie

- **Import + compile:** `-ObjectFile` naar het `.txt`, plus `-Id` van het object
- **Alleen compile:** `-CompileOnly -Id <id>`
- Zonder `-Id` bij import: het script leest de `OBJECT`-header

### Stap 2 — Roep het script aan (niet finsql zelf)

```powershell
powershell -NoProfile -File C:\NAVServices\CRT\kmt-finsql-import.ps1 -ObjectFile 'D:\repos\kmt\objects\COD50070 - Native Artist Pages.txt' -Id 50070
```

```powershell
powershell -NoProfile -File C:\NAVServices\CRT\kmt-finsql-import.ps1 -CompileOnly -Id 50062
```

Defaults (niet wijzigen tenzij de gebruiker dat vraagt): finsql BC14 RTC, database `kmt-test`, server `.`, work dir `C:\NAVServices\CRT`, `synchronizeschemachanges=no`.

### Stap 3 — Rapporteer

Toon de script-output (`IMPORT_OK`, `COMPILE_OK`, of de fout). Bij non-zero exit staan de eerste regels van de finsql-log in de exception. Verzin geen "het zou moeten werken".

## Harde regels

1. **Nooit finsql-argumenten als één komma-string.** PowerShell opent dan de RTC GUI en sterft met "Text kan maximaal 47 tekens lang zijn". Het script gebruikt een `ArgumentList`-array van aparte `'key=value,'` tokens, korte paden, `ntauthentication=1`.
2. **Aanroepen met `-Id 50062`, nooit `-Filter "Type=Codeunit;ID=50062"`.** Een puntkomma in een ongequote filter splitst de caller; finsql hangt op een dialoog.
3. **Eén finsql tegelijk.** Het script neemt een lock en weigert als finsql al draait. Start geen tweede import terwijl er één loopt.
4. **Timeout als finsql niet eindigt** (verborgen dialoog). Bij non-zero exit: eerste regels van de finsql-log. Laat geen hung finsql achter.
5. **Niet `Get-Content -TotalCount` en `-Raw` combineren** — dat gooit en slaat compile over. Het script leest de header alleen met `-TotalCount 1`.
6. **Na import altijd compileren** van dat object-id. Zonder `-Id` leest het script de `OBJECT`-header.
7. Defaults: finsql `C:\Program Files (x86)\Microsoft Dynamics 365 Business Central\140\RoleTailored Client\finsql.exe`, database `kmt-test`, server `.`, work dir `C:\NAVServices\CRT`, `synchronizeschemachanges=no`.
8. C/SIDE-objecttekst: lokale variabele-id's uniek binnen één procedure (parameter en local delen geen `@50000`); procedurenamen geen reserved types (`Page`, `Text`); procedure-id's uniek in het object.

## Regels

- ALTIJD `bc-finsql.md` (plugin knowledge) lezen vóór je iets met finsql doet
- ALTIJD het gebundelde script gebruiken; NOOIT zelf `finsql.exe` argumenten verzinnen
- ALTIJD `-Id`, NOOIT `-Filter` met een puntkomma vanaf de command line
- NOOIT een tweede finsql starten terwijl er één loopt
