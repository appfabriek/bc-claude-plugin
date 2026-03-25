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

### Stap 0 — Check bestaande recepten en projectcontext

1. Lees je **memory** voor geteste AL-snippets (diagnostic recipes). Hergebruik bewezen code in plaats van opnieuw te schrijven.
2. Lees het **workflow YAML** (`bc-diagnostic.yaml`) voor de beschikbare omgevingsnamen — gebruik de exacte waarden uit de `options` lijst.
3. Lees **CLAUDE.md** voor de codebase-architectuur (tabellen, codeunits, velden).

### Stap 1 — Analyseer de vraag

Bepaal uit de beschrijving:
- **Omgeving**: welke BC instance (haal de lijst op uit de workflow)
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
pCduResult.SetObject('key', lJsonObj);     // JSON object
pCduResult.SetArray('key', lJsonArr);      // JSON array
pCduResult.AddRecord('key', lRecRef);      // Record als JSON (alle velden)
pCduResult.Log('debug message');           // Append to _log
pCduResult.SetError('foutmelding');        // Markeer als ERROR
```

**Belangrijke AL-regels:**
- Gebruik `RecordRef` + `FieldRef` voor virtuele/systeem-tabellen
- `RecordRef.SetFilter()` bestaat NIET — gebruik `FieldRef := RecordRef.Field(n); FieldRef.SetFilter(...)`
- Errors worden automatisch opgevangen via TryFunction — je hoeft geen error handling te schrijven

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

```bash
# Wacht tot de run klaar is
gh run watch <run-id> --exit-status

# Lees het resultaat
gh run view <run-id> --log 2>&1 | grep -A 30 "DIAGNOSTIC RESULT"
```

### Stap 5 — Analyseer en rapporteer

Interpreteer het JSON-resultaat en geef een duidelijk antwoord aan de gebruiker. Als het resultaat onvolledig is of meer informatie nodig is, schrijf een vervolgdiagnostic.

### Stap 6 — Itereer indien nodig

Als de eerste diagnostic niet genoeg info geeft, schrijf een verfijndere query en trigger opnieuw. Bouw voort op wat je geleerd hebt.

### Stap 7 — Bewaar nieuwe recepten

Als je een diagnostic hebt geschreven die succesvol was en herbruikbaar is voor toekomstige vragen, voeg het AL-snippet toe aan je diagnostic recipes in memory.

## Doorlooptijd

- Eerste run: ~60s (symbol cache wordt gevuld)
- Volgende runs: ~36s (cache hit)
- Na app update: gebruik `refresh_cache=true`
