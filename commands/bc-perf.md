---
name: bc-perf
description: Scan AL code for performance anti-patterns or profile queries
bc-version: ">=17.0"
allowed-tools: Bash, Read, Write, Glob
---

# BC Performance

Scan AL-code op performance anti-patterns of profileer specifieke queries.

## Input

$ARGUMENTS — modus:
- "--scan" of (leeg) — scan project of git diff op anti-patterns
- "--scan path/to/file.al" — scan specifiek bestand
- "--query <naam>" — genereer diagnostic code om een query te profileren

## Instructies

### Stap 0 — Laad kennis

1. Lees `al-guidelines.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin -name "al-guidelines.md" 2>/dev/null || find ~/code/bc-claude-plugin/knowledge -name "al-guidelines.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   sectie Performance.
2. Lees `bc-architecture-decisions.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin -name "bc-architecture-decisions.md" 2>/dev/null || find ~/code/bc-claude-plugin/knowledge -name "bc-architecture-decisions.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   sectie Performance Architectuur.
3. Lees `diagnostic-recipes.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin -name "diagnostic-recipes.md" 2>/dev/null || find ~/code/bc-claude-plugin/knowledge -name "diagnostic-recipes.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   voor profiling-recepten.

### Modus: --scan

Scan AL-bestanden op deze anti-patterns:

#### P1 — Kritiek (directe productie-impact)

| Pattern | Detectie | Oplossing |
|---------|----------|-----------|
| Missing SetLoadFields | `FindSet`/`FindFirst`/`Get` zonder voorafgaande `SetLoadFields` | Voeg `SetLoadFields` toe |
| IsEmpty + FindSet | `if not .IsEmpty then if .FindSet` | Gebruik alleen `FindSet` |
| CalcFields in loop | `CalcFields` binnen `repeat..until` | Verplaats naar buiten of gebruik query |
| FindSet(true) | Deprecated parameter | Gebruik `LockTable()` + `FindSet()` |
| FIND('-') | Oud NAV patroon | Gebruik `FindSet()` |
| Commit in subscriber | `Commit` in EventSubscriber | Verwijder Commit |
| LockTable te vroeg | `LockTable` aan begin van procedure | Verplaats naar vlak vóór de write |

#### P2 — Belangrijk (schaalbaarheid)

| Pattern | Detectie | Oplossing |
|---------|----------|-----------|
| String concatenatie in loop | `Text += Text` in loop (>5x) | Gebruik `TextBuilder` |
| Missing key voor SetCurrentKey | `SetCurrentKey` op veld zonder index | Voeg key toe of verwijder SetCurrentKey |
| Zware OnAfterGetRecord | Complexe logica in page trigger | Verplaats naar Page Background Task |
| N+1 queries | `Get` of `CalcFields` in loop op gerelateerde tabel | Batch ophalen vóór loop |
| ModifyAll met subscribers | `ModifyAll` op tabel met OnModify subscribers | Overweeg directe SQL via DataTransfer |

#### P3 — Advies (best practice)

| Pattern | Detectie | Oplossing |
|---------|----------|-----------|
| Missing DataAccessIntent | Read-only API/query zonder `ReadOnly` | Voeg `DataAccessIntent = ReadOnly` toe |
| Blob in reguliere tabel | `Blob` veld in transactie-tabel | Verplaats naar apart tabel of gebruik `Media` |

### Rapportage

```
## Performance Scan: <project>

### P1 — Kritiek (3 issues)
- **SalesPostMgt.Codeunit.al:45** — FindSet zonder SetLoadFields
  → Voeg toe: `SalesLine.SetLoadFields("No.", Quantity, Amount)`
- **CustomerSync.Codeunit.al:120** — CalcFields("Balance (LCY)") in loop
  → Overweeg: batch ophalen vóór loop

### P2 — Belangrijk (1 issue)
- **ItemList.Page.al:30** — Zware berekening in OnAfterGetRecord
  → Verplaats naar Page Background Task

### P3 — Advies (0 issues)
Geen issues gevonden.
```

### Modus: --query

Genereer AL diagnostic code voor `/diagnose` die een specifieke query profileert:

```al
    var
        StartTime: DateTime;
        Duration: Integer;
        // query-specifieke variabelen
    begin
        StartTime := CurrentDateTime();
        // voer de query uit
        Duration := CurrentDateTime() - StartTime;
        pCduResult.SetInteger('durationMs', Duration);
        pCduResult.SetInteger('recordCount', RecordCount);
    end;
```

## Regels

- Focus op P1 issues — die hebben directe productie-impact
- Wees specifiek: regelnummer, huidige code, aanbeveling
- Onderscheid nieuwe code (strikt) van legacy (toleranter)
- Bij --query: gebruik `/diagnose` mechanisme voor uitvoering
