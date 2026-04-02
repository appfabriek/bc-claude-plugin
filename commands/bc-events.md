---
name: bc-events
description: List, subscribe to, or publish BC events
bc-version: ">=14.0"
allowed-tools: Bash, Read, Write, Glob
---

# BC Events

Zoek relevante publisher events, genereer subscriber stubs, of publiceer nieuwe events.

## Input

$ARGUMENTS — modus:
- "--list [domein]" — toon relevante events (sales, purchase, finance, inventory, warehouse)
- "--subscribe <event naam>" — genereer subscriber stub
- "--publish <naam>" — genereer nieuwe Business Event definition

## Instructies

### Stap 0 — Laad kennis

1. Lees `bc-events.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin -name "bc-events.md" 2>/dev/null || find ~/code/bc-claude-plugin/knowledge -name "bc-events.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   voor event catalogus en subscriber patterns.
2. Lees `al-guidelines.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin -name "al-guidelines.md" 2>/dev/null || find ~/code/bc-claude-plugin/knowledge -name "al-guidelines.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   voor naamgeving.
3. Lees `bc-architecture-decisions.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin -name "bc-architecture-decisions.md" 2>/dev/null || find ~/code/bc-claude-plugin/knowledge -name "bc-architecture-decisions.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   sectie Event Architectuur.

### Modus: --list [domein]

1. Filter `bc-events.md` op het opgegeven domein
2. Toon per event: naam, codeunit, signature, typisch gebruik
3. Als geen domein → toon de meest gebruikte events uit alle domeinen

### Modus: --subscribe <event naam>

1. Zoek het event in `bc-events.md` of in het project
2. Genereer subscriber codeunit stub:

```al
codeunit <ID> "<PREFIX> <Feature> Event Subscr."
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"<Source>", '<EventName>', '', false, false)]
    local procedure HandleOn<EventName>(/* parameters uit event signature */)
    begin
        // TODO: implement
    end;
}
```

3. Adviseer over:
   - `IsHandled` pattern (als van toepassing)
   - Geen `Commit` in subscriber
   - Performance implicaties bij table events

### Modus: --publish <naam>

1. Genereer Business Event publisher:

```al
[BusinessEvent(true)]
procedure On<EventName>(/* parameters */)
begin
end;
```

2. Adviseer:
   - `[BusinessEvent]` voor Power Automate / externe consumers
   - `[IntegrationEvent]` voor andere AL-apps
   - `[InternalEvent]` voor interne gebruik
   - Signature nooit meer wijzigen na release bij BusinessEvent

## Regels

- Subscriber codeunit: één per feature-area
- Nooit `Commit` in subscribers
- `false, false` voor binding parameters (standaard)
- Lees `bc-events.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin -name "bc-events.md" 2>/dev/null || find ~/code/bc-claude-plugin/knowledge -name "bc-events.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   voor alle event signatures
