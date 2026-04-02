---
name: bc-test
description: Generate and run AL test codeunits
bc-version: ">=15.0"
allowed-tools: Bash, Read, Write, Glob
---

# BC Test

Genereer AL-testcodeunits en voer ze uit.

## Input

$ARGUMENTS — optionele instructies, bijvoorbeeld:
- (leeg) — genereer tests voor recent gewijzigde codeunits
- "SalesOrderMgt" — genereer tests voor specifieke codeunit
- "run" — voer bestaande tests uit
- "run 50150" — voer specifieke test codeunit uit

## Instructies

### Stap 0 — Laad kennis

1. Lees `bc-test-patterns.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin -name "bc-test-patterns.md" 2>/dev/null || find ~/code/bc-claude-plugin/knowledge -name "bc-test-patterns.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   voor test-structuur en patronen.
2. Lees `al-guidelines.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin -name "al-guidelines.md" 2>/dev/null || find ~/code/bc-claude-plugin/knowledge -name "al-guidelines.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   voor naamgeving.
3. Lees `app.json` → `idRanges` voor test object IDs.
4. Lees `bc-version-matrix.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin -name "bc-version-matrix.md" 2>/dev/null || find ~/code/bc-claude-plugin/knowledge -name "bc-version-matrix.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   → check of test framework beschikbaar is.

### Stap 1 — Bepaal modus

**Genereren:**
- Als een codeunit-naam is opgegeven → lees die codeunit
- Als leeg → lees `git diff` voor recent gewijzigde codeunits

**Uitvoeren:**
- Als "run" → ga naar Stap 4

### Stap 2 — Analyseer de target codeunit

Lees de codeunit en identificeer:
- Publieke procedures die getest moeten worden
- Record-operaties (Insert, Modify, Delete)
- Externe calls (HTTP, events)
- Error-paden (TestField, Error, TryFunction)
- UI-interacties (Message, Confirm, Page.Run)

### Stap 3 — Genereer test codeunit

Volg het Given/When/Then patroon uit `bc-test-patterns.md`:

```al
codeunit <ID> "<App Prefix> <Feature> Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit Assert;
        IsInitialized: Boolean;

    local procedure Initialize()
    begin
        if IsInitialized then
            exit;
        // Eenmalige setup
        IsInitialized := true;
    end;

    [Test]
    procedure <ProcedureName>_<Scenario>_<Expected>()
    begin
        // GIVEN
        Initialize();
        // setup

        // WHEN
        // actie

        // THEN
        // assertie
    end;
}
```

**Testnaam-conventie:** `ProcedureName_Scenario_ExpectedResult`

**Per publieke procedure, genereer minimaal:**
1. Happy path test
2. Eén fout-scenario (als er TestField/Error calls zijn)
3. Handler als er UI-interactie is

Gebruik Library codeunits (`Library - Sales`, `Library - Purchase`, etc.) voor testdata.

### Stap 4 — Voer tests uit

**Via GitHub Actions (als `bc-diagnostic.yaml` beschikbaar):**

```bash
cat > /tmp/diag.al << 'ALEOF'
    var
        TestResult: Text;
    begin
        // Gebruik CODEUNIT.Run met test isolation
        pCduResult.Set('result', 'Tests must be run via Test Tool or REST endpoint');
        pCduResult.Log('Use /bc-ps run tests for container-based execution');
    end;
ALEOF
```

**Via REST endpoint:**
Het standaard BC dev-endpoint ondersteunt geen directe test-executie via REST.
Gebruik BcContainerHelper (hieronder) of GitHub Actions voor test-executie.

**Via BcContainerHelper (als container beschikbaar):**

Genereer het PowerShell script en adviseer de gebruiker:

```powershell
Run-TestsInBcContainer `
    -containerName '<container>' `
    -credential $Cred `
    -testCodeunit <ID> `
    -detailed `
    -XUnitResultFileName './testresults.xml'
```

### Stap 5 — Rapporteer

**Bij genereren:**
- Aantal tests gegenereerd
- Welke scenario's gedekt
- Ontbrekende handlers (als er UI-interacties zijn)

**Bij uitvoeren:**
- Geslaagd / Gefaald per test
- Foutmelding bij gefaalde tests
- Suggesties voor fixes

## Regels

- Gebruik ALTIJD Given/When/Then patroon
- Eén assertie-concept per test
- Gebruik Library codeunits voor testdata — geen hardcoded record IDs
- Nooit `Commit` in tests
- Altijd `[HandlerFunctions]` als de code UI-interacties bevat
- Test codeunit naam: `"<Prefix> <Feature> Tests"`
- Test IDs: gebruik een apart bereik binnen `idRanges` (bijv. laatste 50 IDs)
