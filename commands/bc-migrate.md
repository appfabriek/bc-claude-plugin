---
name: bc-migrate
description: Assist with BC version migration (e.g. BC14→BC27)
bc-version: ">=14.0"
---

# BC Migrate

Help bij migratie van AL-code tussen BC-versies.

## Input

$ARGUMENTS — optionele versie-specificatie:
- "--from 21 --to 26" — migreer van BC21 naar BC26
- (leeg) — detecteer huidige versie uit app.json en adviseer naar latest

## Instructies

### Stap 0 — Laad kennis

1. Lees `knowledge/bc-version-matrix.md` voor feature-beschikbaarheid en deprecations.
2. Lees `knowledge/al-guidelines.md` voor huidige best practices.
3. Lees `knowledge/bc-architecture-decisions.md` voor architectuurbeslissingen.
4. Lees `app.json` → `runtime`, `platform`, `application`.

### Stap 1 — Bepaal migratiepaden

Op basis van bron- en doelversie, identificeer:

#### Deprecated Features

| Van | Naar | Wijziging |
|-----|------|-----------|
| <22 | ≥22 | `FindSet(true)` → `LockTable()` + `FindSet()` |
| <22 | ≥22 | Tri-state locking beschikbaar |
| <24 | ≥24 | Web Service Access Keys deprecated |
| <26 | ≥26 | SOAP services deprecated |
| <22 | ≥22 | Namespaces beschikbaar (optioneel) |

#### Nieuwe Features (aanbevolen)

| Versie | Feature | Toepassing |
|--------|---------|------------|
| BC 17 | `SetLoadFields` | Voeg toe aan alle Find/Get calls |
| BC 18 | PermissionSet objects | Vervang XML permission sets |
| BC 20 | `DataTransfer` | Gebruik in upgrade codeunits |
| BC 22 | API Query type | Nieuwe read-only APIs |
| BC 24 | Copilot toolkit | AI capabilities |
| BC 26 | Rendering layout syntax | Vervang RDLCLayout/WordLayout properties |

### Stap 2 — Scan project

```bash
# Zoek deprecated patronen
grep -rn "FindSet(true)" --include="*.al" .
grep -rn "FIND('-')" --include="*.al" .
grep -rn "DotNet\b" --include="*.al" .
grep -rn "RDLCLayout\|WordLayout" --include="*.al" .  # deprecated layout properties
```

Per gevonden patroon: rapporteer bestand, regelnummer, en migratie-actie.

### Stap 3 — Genereer migratie-checklist

```
## Migratie Checklist: BC<van> → BC<naar>

### Verplicht (breekt compilatie)
- [ ] Vervang `FindSet(true)` door `LockTable()` + `FindSet()` (12 locaties)
- [ ] Verwijder `DotNet` interop (3 locaties) — vervang door `HttpClient`

### Aanbevolen (performance/modernisering)
- [ ] Voeg `SetLoadFields` toe (23 FindSet/Get calls zonder)
- [ ] Migreer XML permission sets naar AL PermissionSet objecten
- [ ] Update `runtime` in app.json naar "<doelversie>"
- [ ] Update `platform` en `application` versies

### Optioneel (nieuwe mogelijkheden)
- [ ] Overweeg API Query type voor read-only endpoints
- [ ] Overweeg Copilot capability als relevant
```

### Stap 4 — Update app.json

Stel de juiste versie-waarden voor:
```json
{
    "runtime": "<nieuwe runtime>",
    "platform": "<nieuwe platform>.0.0.0",
    "application": "<nieuwe application>.0.0.0"
}
```

## Regels

- Scan ALTIJD het hele project, niet alleen gewijzigde bestanden
- Prioriteer: eerst verplichte wijzigingen, dan aanbevolen, dan optioneel
- Gebruik `knowledge/bc-version-matrix.md` als autoritieve bron
- Bied aan om gevonden issues automatisch te fixen (als eenvoudig)
