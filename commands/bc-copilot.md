---
name: bc-copilot
description: Scaffold a BC Copilot capability (System.AI module)
bc-version: ">=24.0"
allowed-tools: Bash, Read, Write, Glob
---

# BC Copilot

Scaffold een volledige BC Copilot capability met registratie, AzureOpenAI setup, metaprompt en PromptDialog page.

## Input

$ARGUMENTS — capability naam en optionele context:
- "Suggest Sales Lines" — genereer complete Copilot capability
- "Analyze Customer Data" — capability met custom prompt

## Instructies

### Stap 0 — Laad kennis

1. Lees `bc-copilot-patterns.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin/knowledge ./.claude/plugins/bc-claude-plugin/knowledge ~/.local/share/claude/plugins/bc-claude-plugin/knowledge ~/code/bc-claude-plugin/knowledge -name "bc-copilot-patterns.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   voor System.AI namespace, registratie, PromptDialog.
2. Lees `bc-version-matrix.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin/knowledge ./.claude/plugins/bc-claude-plugin/knowledge ~/.local/share/claude/plugins/bc-claude-plugin/knowledge ~/code/bc-claude-plugin/knowledge -name "bc-version-matrix.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   → CopilotCapability vereist BC 24+, PromptDialog BC 24+.
3. Lees `al-guidelines.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin/knowledge ./.claude/plugins/bc-claude-plugin/knowledge ~/.local/share/claude/plugins/bc-claude-plugin/knowledge ~/code/bc-claude-plugin/knowledge -name "al-guidelines.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   voor naamgeving.
4. Lees `app.json` → `idRanges`, prefix, `runtime` (moet >= 13.0 zijn).

### Stap 1 — Verifieer compatibility

- Check `runtime` in `app.json` — moet >= `13.0` (BC 24) zijn
- Als te laag → meld dit en stop

### Stap 2 — Genereer objecten

Maak de volgende objecten aan:

1. **Enum Extension** — registreer capability:
   ```al
   enumextension <ID> "<PREFIX> Copilot Capabilities" extends "Copilot Capability"
   {
       value(<ID>; "<PREFIX> <Capability Name>")
       {
           Caption = '<Capability Name>';
       }
   }
   ```

2. **Install Codeunit** — registreer bij installatie:
   - Volg `bc-copilot-patterns.md` install patroon

3. **Upgrade Codeunit** — registreer bij upgrade:
   - Volg `bc-copilot-patterns.md` upgrade patroon

4. **Suggest Codeunit** — AzureOpenAI aanroep:
   - System prompt (metaprompt) met duidelijke instructies
   - Temperature, max tokens configuratie
   - Error handling bij niet-beschikbaarheid

5. **PromptDialog Page** — UI:
   - Prompt area (user input)
   - Content area (suggestions)
   - SystemActions: Generate, OK, Cancel, Regenerate

6. **Suggestions Subpage** — resultaat tabel/lijst

### Stap 3 — Metaprompt

Genereer een contextspecifiek systeem-prompt:
- Duidelijke rol en taak
- Output format (JSON voor gestructureerde data)
- Constraints (geen PII genereren, alleen bestaande entiteiten)
- 1-2 voorbeelden

### Stap 4 — Billing en Governance

Adviseer de gebruiker:
- **Microsoft Billed:** standaard voor AppSource apps
- **Custom Billed:** vereist eigen Azure OpenAI resource
- Voeg telemetry toe voor Copilot-gebruik tracking

### Stap 5 — Rapporteer

- Lijst van gegenereerde objecten
- Activatie-instructie: "Ga naar Copilot & AI Capabilities in BC om te activeren"
- Verwijs naar `bc-copilot-patterns.md` voor verdere aanpassing

## Regels

- ALTIJD capability registreren in ZOWEL install als upgrade codeunit
- ALTIJD `AzureOpenAI.IsEnabled()` checken vóór aanroep
- ALTIJD transparantie: toon dat content AI-gegenereerd is
- ALTIJD telemetry toevoegen voor Copilot-gebruik
- Lees `bc-copilot-patterns.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin/knowledge ./.claude/plugins/bc-claude-plugin/knowledge ~/.local/share/claude/plugins/bc-claude-plugin/knowledge ~/code/bc-claude-plugin/knowledge -name "bc-copilot-patterns.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   voor alle patronen
