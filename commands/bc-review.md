---
name: bc-review
description: Review AL code against Microsoft guidelines and best practices
bc-version: ">=14.0"
allowed-tools: Bash, Read, Write
---

# BC Review

Review AL-code tegen Microsoft-richtlijnen en bewezen patronen. Rapporteer verbeterpunten zonder zelf code te wijzigen (tenzij gevraagd).

## Input

$ARGUMENTS — optionele instructies, bijvoorbeeld:
- (leeg) — review git diff (gewijzigde bestanden)
- "bestand.al" — review specifiek bestand
- "map/" — review alle AL-bestanden in een map
- "fix" — review + direct corrigeren
- "performance" — focus op performance-issues

## Instructies

### Stap 0 — Laad richtlijnen

Lees `al-guidelines.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin/knowledge ./.claude/plugins/bc-claude-plugin/knowledge ~/.local/share/claude/plugins/bc-claude-plugin/knowledge ~/code/bc-claude-plugin/knowledge -name "al-guidelines.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
    Dit is de reviewchecklist.

### Stap 1 — Bepaal scope

**Als git diff (standaard):**
```bash
cd "<project>"
git diff --name-only HEAD | grep "\.al$"
```

**Als specifiek bestand/map:** gebruik het opgegeven pad.

Lees alle AL-bestanden in scope.

### Stap 2 — Review per bestand

Controleer elk bestand op de volgende categorieën:

#### Naamgeving (Microsoft officieel)

- [ ] Variabelen: PascalCase, objectnaam in de naam (`SalesHeader` niet `Rec`)
- [ ] Temporary records: `Temp` prefix (`TempItem: Record Item temporary`)
- [ ] Procedures: PascalCase, beschrijvende actienaam
- [ ] Procedure-aanroepen: altijd haakjes (`Init()`, niet `Init`)
- [ ] Labels: `Err` suffix voor errors, `Qst` voor vragen, `Tok` voor constanten
- [ ] `Locked = true` op labels die niet vertaald mogen worden (URLs, codes)
- [ ] Keywords lowercase (`begin`, `end`, `if`), built-in methods PascalCase

#### Performance

- [ ] `SetLoadFields` vóór `Get`/`FindFirst`/`FindSet` als niet alle velden nodig zijn
- [ ] Geen `IsEmpty` + `FindSet` combinatie (36% trager dan alleen `FindSet`)
- [ ] `SetRange` waar mogelijk in plaats van `SetFilter` voor eenvoudige gelijkheid
- [ ] `LockTable()` of `ReadIsolation := UpdLock` vóór `FindSet()` als records in de loop worden gewijzigd (`FindSet(true)` is deprecated sinds BC v22)
- [ ] `TextBuilder` voor 5+ string-concatenaties
- [ ] Geen `CalcFields` in loops als het buiten de loop kan
- [ ] `LockTable` zo laat mogelijk (niet aan begin procedure)

#### Foutafhandeling

- [ ] Geen `Commit` in event subscribers of library-codeunits
- [ ] Geen `Commit` in `OnValidate` triggers
- [ ] `[TryFunction]` met `GetLastErrorText()` bij externe calls
- [ ] `TestField` in plaats van handmatige lege-veld checks

#### Architectuur

- [ ] Business logic in codeunits, niet in page/table triggers
- [ ] Objectvolgorde: Properties → Constructs → Variables → Triggers → Procedures
- [ ] Labels vóór andere globale variabelen
- [ ] Publieke procedures vóór lokale procedures

#### Data-integriteit

- [ ] `DataClassification` op elk tabelveld (niet `ToBeClassified`)
- [ ] `ObsoleteState` / `ObsoleteReason` op deprecated velden/objecten

### Stap 3 — Rapporteer

Groepeer bevindingen per categorie. Gebruik dit formaat:

```
## Review: [bestandsnaam]

### Performance (X issues)
- **Regel Y:** `Customer.FindSet()` zonder `SetLoadFields` — voeg toe: `Customer.SetLoadFields("No.", Name)`
- **Regel Z:** `IsEmpty` gevolgd door `FindSet` — gebruik alleen `FindSet`

### Naamgeving (X issues)
- **Regel Y:** variabele `Rec` → hernoem naar `SalesHeader` (objectnaam in variabelenaam)

### Geen issues gevonden
Architectuur, Foutafhandeling, Data-integriteit: OK
```

**Prioritering:**
1. **Performance** — directe impact op productie
2. **Foutafhandeling** — voorkomt dataloss/crashes
3. **Data-integriteit** — compliance/security
4. **Architectuur** — onderhoudbaarheid
5. **Naamgeving** — leesbaarheid

### Stap 4 — Fix (alleen als gevraagd)

Als de gebruiker "fix" heeft opgegeven:
1. Pas alleen automatisch te corrigeren issues aan (naamgeving, SetLoadFields toevoegen)
2. Laat complexe issues staan met een comment `// TODO: [beschrijving]`
3. Compileer na wijzigingen om te verifiëren dat niets breekt

## Regels

- Rapporteer ALLEEN echte issues, geen style-preferences
- Wees specifiek: noem het regelnummer, de huidige code, en de aanbeveling
- Onderscheid NIEUWE code (strikt) van BESTAANDE code (toleranter) — meld legacy-patronen als "overweeg te moderniseren" niet als "fout"
- Bij "fix": wijzig NOOIT bestaande procedure-signatures (breekt API)
- Meld geen issues in gegenereerde bestanden (.g.xlf, .alpackages, etc.)
