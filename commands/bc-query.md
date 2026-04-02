# BC Query

Stel datavragen aan een BC-omgeving in gewoon Nederlands. Claude schrijft de AL-code, voert de diagnostic uit, en presenteert het resultaat.

## Input

$ARGUMENTS — datavraag in gewoon Nederlands, bijvoorbeeld:
- "hoeveel open verkooporders op productie"
- "top 10 klanten op saldo, omgeving dev"
- "welke jobs staan op error op accept"
- "hoeveel items zijn er in omgeving X"
- "toon de laatste 20 geboekte verkoopfacturen op productie"

## Instructies

### Stap 0 — Laad kennis

1. Lees **`knowledge/bc-tables.md`** uit de plugin directory voor tabelnamen, veldnummers en opties.
2. Lees **`knowledge/diagnostic-recipes.md`** voor bewezen snippets die je kunt hergebruiken.
3. Lees **`knowledge/al-guidelines.md`** voor AL-patronen (SetLoadFields, SetRange, etc.)
4. Lees het **workflow YAML** (`bc-diagnostic.yaml`) voor de beschikbare omgevingsnamen.

### Stap 1 — Analyseer de vraag

Bepaal uit de beschrijving:
- **Omgeving**: welke BC instance. Als niet opgegeven → vraag de gebruiker.
- **Tabel(len)**: welke BC-tabellen relevant zijn (gebruik `bc-tables.md`)
- **Filters**: welke velden gefilterd moeten worden
- **Output**: wat de gebruiker wil zien (telling, lijst, top-N)
- **Company**: indien relevant (standaard leeg)

### Stap 2 — Schrijf AL diagnostic code

Schrijf de body van `Execute(var pCduResult: Codeunit "Diagnostic Result")`.

**Patronen per vraagtype:**

**Telling:**
```al
    var
        SalesHeader: Record "Sales Header";
    begin
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.SetRange(Status, SalesHeader.Status::Open);
        pCduResult.SetInteger('count', SalesHeader.Count());
    end;
```

**Lijst (top-N):**
```al
    var
        Customer: Record Customer;
        ResultArray: JsonArray;
        ResultObject: JsonObject;
        Counter: Integer;
    begin
        // SetLoadFields geldt alleen voor fysieke velden, niet voor FlowFields
        Customer.SetLoadFields("No.", Name);
        if Customer.FindSet() then
            repeat
                Customer.CalcFields("Balance (LCY)");
                if Customer."Balance (LCY)" > 0 then begin
                    Counter += 1;
                    Clear(ResultObject);
                    ResultObject.Add('no', Customer."No.");
                    ResultObject.Add('name', Customer.Name);
                    ResultObject.Add('balance', Customer."Balance (LCY)");
                    ResultArray.Add(ResultObject);
                end;
            until (Customer.Next() = 0) or (Counter >= 10);
        pCduResult.SetArray('results', ResultArray);
        pCduResult.SetInteger('count', ResultArray.Count());
    end;
```

**Regels voor de AL-code:**
- Gebruik `SetLoadFields` als je niet alle velden nodig hebt
- Beperk resultaten met counter (max ~100 records)
- Gebruik `SetRange` voor eenvoudige filters, `SetFilter` voor wildcards/OR
- `CalcFields` alleen voor FlowFields en alleen als je de waarde nodig hebt
- Gebruik `RecordRef` + `FieldRef` voor virtuele/systeem-tabellen

### Stap 3 — Trigger diagnostic

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

Voeg `-f company="<naam>"` toe indien nodig.

**BELANGRIJK:** Self-hosted runners draaien sequentieel. Nooit meerdere runs parallel triggeren.

### Stap 4 — Haal resultaat op

```bash
sleep 3
RUN_ID=$(gh run list --workflow=bc-diagnostic.yaml --limit=1 --json databaseId -q '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status
gh run view "$RUN_ID" --log 2>&1 | grep -A 30 "DIAGNOSTIC RESULT"
```

### Stap 5 — Presenteer resultaat

Vertaal het JSON-resultaat naar een leesbaar antwoord:

- **Tellingen:** "Er zijn 47 open verkooporders op productie."
- **Lijsten:** tabel met kolommen, gesorteerd
- **Fouten:** "De query is mislukt: [foutmelding]" + suggestie voor correctie

Gebruik geen technisch jargon tenzij de gebruiker er expliciet om vraagt. De gebruiker hoeft de AL-code niet te zien.

### Stap 6 — Vervolgvragen

Als de gebruiker doorvraagt ("en op accept?", "filter op klant X"), hergebruik de vorige query met aangepaste parameters. Trigger sequentieel.

## Regels

- Dit is een **conversationele** interface — geen AL-kennis vereist van de gebruiker
- Toon de AL-code NIET tenzij de gebruiker erom vraagt
- Gebruik ALTIJD `knowledge/bc-tables.md` voor veldnummers — raad ze niet
- Beperk resultaten — nooit meer dan 100 records ophalen
- Bij twijfel over de omgeving: VRAAG, niet raden
