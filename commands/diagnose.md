---
name: diagnose
description: Run remote AL diagnostics on a BC environment via GitHub Actions
bc-version: ">=14.0"
allowed-tools: Bash, Read, Write, Glob
---

# BC Remote Diagnostic

Voer een remote diagnostic uit op een BC-omgeving via de GitHub Actions diagnostic workflow.

## Input

$ARGUMENTS — beschrijving van wat je wilt diagnosticeren. Voorbeelden:
- "check of listener X actief is op omgeving Y"
- "hoeveel open documenten zijn er op omgeving Z"
- "welke versie van extensie X draait op omgeving Y"
- "reproduceer de error die optreedt bij actie X op omgeving Y"

## Instructies

Je bent een BC AL-developer die remote diagnostics uitvoert. Volg dit proces:

### Stap 0 — Laad kennis en check recepten

1. Lees `diagnostic-recipes.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin -name "diagnostic-recipes.md" 2>/dev/null || find ~/code/bc-claude-plugin/knowledge -name "diagnostic-recipes.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
    Hergebruik bewezen code in plaats van opnieuw te schrijven.
2. Lees `bc-tables.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin -name "bc-tables.md" 2>/dev/null || find ~/code/bc-claude-plugin/knowledge -name "bc-tables.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   voor tabel-referenties (veldnummers, opties, etc.)
3. Lees `al-guidelines.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin -name "al-guidelines.md" 2>/dev/null || find ~/code/bc-claude-plugin/knowledge -name "al-guidelines.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   voor AL-patronen (SetLoadFields, RecordRef, etc.)
4. Lees het **workflow YAML** (`bc-diagnostic.yaml`) voor de beschikbare omgevingsnamen — gebruik de exacte waarden uit de `options` lijst.
5. Lees **CLAUDE.md** van het project voor codebase-architectuur (tabellen, codeunits, velden).
6. Lees je **memory** voor eerder geteste snippets die niet in recipes staan.

### Stap 1 — Analyseer de vraag

Bepaal uit de beschrijving:
- **Omgeving**: welke BC instance (haal de lijst op uit de workflow). Als er maar één omgeving is, gebruik die automatisch.
- **Wat te doen**: welke tabellen/codeunits/functies relevant zijn
- **Company**: indien relevant (standaard leeg)

### Stap 2 — Schrijf de AL diagnostic code

Schrijf de body van de `Execute(var pCduResult: Codeunit "Diagnostic Result")` procedure. Dit is alles na de procedure signature: de `var` sectie en het `begin`/`end` block.

De diagnostic app heeft een dependency op de hoofd-app (zie `diagnostic/template/app.json`), dus je kunt alle publieke types uit de hoofd-app gebruiken. Daarnaast kun je `RecordRef` gebruiken voor systeem- en virtuele tabellen.

**Result helper API** (beschikbaar via `pCduResult`):
```al
pCduResult.Set('key', 'textvalue');        // Text
pCduResult.SetInteger('key', 42);          // Integer
pCduResult.SetDecimal('key', 3.14);        // Decimal
pCduResult.SetBoolean('key', true);        // Boolean
pCduResult.SetObject('key', ResultObject);  // JSON object
pCduResult.SetArray('key', ResultArray);   // JSON array
pCduResult.AddRecord('key', SourceRecord); // Record als JSON (alle velden)
pCduResult.Log('debug message');           // Append to _log
pCduResult.SetError('foutmelding');        // Markeer als ERROR
```

**Belangrijke AL-regels:**
- Gebruik `RecordRef` + `FieldRef` voor virtuele/systeem-tabellen (tabel > 2000000000)
- `RecordRef.SetFilter()` bestaat NIET — gebruik `FieldRef := RecordRef.Field(n); FieldRef.SetFilter(...)`
- Errors worden automatisch opgevangen via TryFunction — je hoeft geen error handling te schrijven
- Gebruik `SetLoadFields` als je niet alle velden nodig hebt
- Beperk resultaten met een counter (max ~100 records) om timeouts te voorkomen

### Stap 3 — Schrijf naar temp bestand en trigger

**BELANGRIJK: Self-hosted runners kunnen maar 1 job tegelijk draaien. Trigger NOOIT meerdere runs parallel — ze worden gecanceld. Bij meerdere omgevingen: trigger sequentieel (trigger → watch → resultaat → volgende).**

```bash
cat > /tmp/diag.al << 'ALEOF'
    var
        ...
    begin
        ...
    end;
ALEOF

gh workflow run bc-diagnostic.yaml \
  -f environment="<omgeving>" \
  -F al_code=@/tmp/diag.al
```

Optionele flags:
- `-f company="<company name>"` — specifieke company
- `-f keep_installed=true` — laat diagnostic app staan na run
- `-f refresh_cache=true` — ververs symbol cache

### Stap 4 — Wacht op resultaat

Haal automatisch de run-ID op en wacht:

```bash
# Wacht even tot de run geregistreerd is
sleep 3

# Haal de laatste run-ID op
RUN_ID=$(gh run list --workflow=bc-diagnostic.yaml --limit=1 --json databaseId -q '.[0].databaseId')

# Wacht tot klaar
gh run watch "$RUN_ID" --exit-status

# Lees het resultaat
gh run view "$RUN_ID" --log 2>&1 | grep -A 30 "DIAGNOSTIC RESULT"
```

### Stap 5 — Analyseer en rapporteer

Interpreteer het JSON-resultaat en geef een duidelijk antwoord aan de gebruiker. Als het resultaat onvolledig is of meer informatie nodig is, schrijf een vervolgdiagnostic.

### Stap 6 — Itereer indien nodig

Als de eerste diagnostic niet genoeg info geeft, schrijf een verfijndere query en trigger opnieuw. Bouw voort op wat je geleerd hebt.

### Stap 7 — Bewaar nieuwe recepten

Als je een diagnostic hebt geschreven die succesvol was en herbruikbaar is:
1. Voeg het AL-snippet toe aan je **memory** als diagnostic recipe
2. Overweeg of het ook in `diagnostic-recipes.md` (plugin knowledge) thuishoort (generiek genoeg voor alle projecten)

## Doorlooptijd

- Eerste run: ~60s (symbol cache wordt gevuld)
- Volgende runs: ~36s (cache hit)
- Na app update: gebruik `refresh_cache=true`
