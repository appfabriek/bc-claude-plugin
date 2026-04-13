---
name: bc-translate
description: Sync translations across all XLF language files
bc-version: ">=14.0"
allowed-tools: Bash, Read, Write
---

# BC Translate

Synchroniseer vertalingen: voeg ontbrekende trans-units toe aan alle taalbestanden na wijzigingen in AL-code.

## Input

$ARGUMENTS — optionele instructies, bijvoorbeeld:
- (leeg) — scan git diff voor nieuwe/gewijzigde Caption, ToolTip, Label
- "bestand.al" — scan specifiek bestand
- "alle" — scan alle AL-bestanden in het project
- "check" — rapporteer alleen ontbrekende vertalingen, wijzig niets
- `nl="tekst"` — geef een bekende Nederlandse vertaling mee voor een specifieke Engelse source (zie Stap 3b)

Meerdere vertalingen kunnen worden meegegeven als key=value paren, bijv.:
```
/bc-translate nl="Naar SCADA planning verzonden" nl2="Updates verwerkt"
```
Of als expliciete source→target mapping (wanneer er meerdere verschillende labels zijn):
```
/bc-translate "Sent to SCADA planning"=>"Naar SCADA planning verzonden" "Updates processed"=>"Updates verwerkt"
```

## Instructies

### Stap 0 — Lees projectcontext

1. Lees `al-guidelines.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin/knowledge ./.claude/plugins/bc-claude-plugin/knowledge ~/.local/share/claude/plugins/bc-claude-plugin/knowledge ~/code/bc-claude-plugin/knowledge -name "al-guidelines.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   
2. Zoek het AL-project: de map met `app.json`.
3. Lees `app.json` → `name` (gebruikt in XLF-bestandsnamen).
4. Controleer of `"features": ["TranslationFile"]` aan staat in `app.json`. Zo niet → meld dit en stop.

### Stap 1 — Zoek taalbestanden

Zoek alle XLF-bestanden in het project:

```bash
find "<project>" -name "*.xlf" -not -path "*/.alpackages/*" | sort
```

Verwachte bestanden:
- `<AppName>.g.xlf` — master (gegenereerd door compiler, source only)
- `<AppName>.<lang>.xlf` — taalbestanden (source + target)

**Ondersteunde talen:** nl-NL, nl-BE, fr-FR, fr-BE, de-DE

Als er taalbestanden ontbreken → meld welke er missen, maar ga door met de bestanden die er zijn.

### Stap 2 — Lees het master-bestand

Lees `<AppName>.g.xlf` en extraheer alle trans-unit IDs met hun source-tekst.

Structuur van een trans-unit:
```xml
<trans-unit id="Table 123 - Field 456 - Property 2879900210" size-unit="char" maxwidth="0" al-object-target="..." translate="yes">
  <source>Customer Name</source>
  <note from="Xliff Generator" annotates="general" priority="3">Table MyTable - Field CustomerName - Property Caption</note>
</trans-unit>
```

### Stap 3 — Bepaal scope

**Als git diff (standaard):**
```bash
cd "<project>"
git diff --name-only HEAD | grep "\.al$"
```
Filter de master XLF op trans-units waarvan de `note` verwijst naar objecten in gewijzigde bestanden.

**Als specifiek bestand:** Filter op objectnaam uit dat bestand.

**Als "alle":** Gebruik alle trans-units uit de master.

### Stap 3b — Detecteer bekende vertalingen

Bouw een mapping van Engelse source → bekende vertalingen op via twee bronnen:

**A. Automatisch uit de git diff (voor refactor-commits):**

Scan de diff van gewijzigde AL-bestanden op vervangen hardcoded strings:
```bash
git diff HEAD~1 HEAD -- [gewijzigde .al bestanden]
```
Zoek naar patronen waarbij een hardcoded NL string (`- Message('...')`, `- Error('...')`) is vervangen door een Label-aanroep, terwijl het Label zelf een Engelse source krijgt (`+ Label '...'`). Bijvoorbeeld:
```
-        Message('Naar SCADA planning verzonden');
+        Message(TextSCADA);
...
+        TextSCADA: Label 'Sent to SCADA planning';
```
→ mapping: `"Sent to SCADA planning"` → `nl-NL: "Naar SCADA planning verzonden"`, `nl-BE: "Naar SCADA planning verzonden"`

Ondersteunde patronen: `Message(...)`, `Error(...)`, `Confirm(...)`, `StrSubstNo(...)`.

**B. Expliciet via $ARGUMENTS:**

Scan $ARGUMENTS op `"Engelse tekst"=>"NL tekst"` paren. De NL tekst geldt voor zowel nl-NL als nl-BE, tenzij anders opgegeven.

**Prioriteit:** expliciete input overschrijft auto-detectie.

### Stap 4 — Vergelijk met taalbestanden

Voor elk taalbestand (`<AppName>.<lang>.xlf`):
1. Lees alle bestaande trans-unit IDs
2. Vergelijk met de master
3. Identificeer:
   - **Ontbrekend:** trans-unit ID in master maar niet in taalbestand
   - **Verouderd:** trans-unit ID in taalbestand maar niet meer in master (optioneel melden)

### Stap 5 — Voeg ontbrekende trans-units toe

Voor elke ontbrekende trans-unit, bepaal eerst of er een bekende vertaling is uit Stap 3b:

**Als de vertaling bekend is voor deze taal** (bijv. nl-NL via auto-detectie of expliciete input):
```xml
<trans-unit id="[id uit master]" translate="yes">
  <source>[source uit master]</source>
  <target state="translated">[bekende vertaling]</target>
  <note from="Xliff Generator" annotates="general" priority="3">[note uit master]</note>
</trans-unit>
```

**Als de vertaling onbekend is:**
```xml
<trans-unit id="[id uit master]" translate="yes">
  <source>[source uit master]</source>
  <target state="needs-translation">[source als fallback]</target>
  <note from="Xliff Generator" annotates="general" priority="3">[note uit master]</note>
</trans-unit>
```

**Regels:**
- Gebruik `state="translated"` + bekende tekst wanneer de vertaling bekend is
- Gebruik `state="needs-translation"` + Engelse fallback wanneer de vertaling onbekend is
- Voeg toe binnen de `<group id="body">` sectie, gesorteerd op ID
- Behoud bestaande vertalingen — overschrijf NOOIT een bestaande target

### Stap 6 — Rapporteer

Toon per taalbestand:
- Aantal toegevoegde trans-units
- Lijst van toegevoegde captions (kort)
- Eventueel verouderde trans-units die niet meer in de master staan

Voorbeeld output:
```
Vertalingen bijgewerkt:
  nl-NL: +3 trans-units vertaald (Customer Name, Order Status, Ship Date)
  nl-BE: +3 trans-units vertaald
  fr-FR: +3 trans-units → needs-translation
  fr-BE: +3 trans-units → needs-translation
  de-DE: +3 trans-units → needs-translation

Let op: 1 verouderde trans-unit gevonden (Old Field Caption) — handmatig verwijderen indien gewenst.
```

Vermeld expliciet welke vertalingen automatisch gedetecteerd werden uit de git diff.

## Regels

- Overschrijf NOOIT bestaande vertalingen (targets met state="translated" of "final")
- Voeg ALTIJD toe aan ALLE taalbestanden, niet slechts één
- Gebruik ALTIJD `state="needs-translation"` voor nieuwe entries
- Controleer of `"features": ["TranslationFile"]` aan staat
- Labels met `Locked = true` verschijnen NIET in de XLF — dat is correct, niet melden als ontbrekend
