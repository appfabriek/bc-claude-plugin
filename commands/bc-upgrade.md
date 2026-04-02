---
name: bc-upgrade
description: Analyze and generate upgrade codeunits for schema changes
bc-version: ">=18.0"
allowed-tools: Bash, Read, Write, Glob
---

# BC Upgrade

Analyseer schema-wijzigingen en genereer upgrade-codeunits.

## Input

$ARGUMENTS — modus:
- "--analyze" of (leeg) — detecteer wijzigingen die upgrade-logica nodig hebben
- "--generate" — schrijf upgrade + install codeunits

## Instructies

### Stap 0 — Laad kennis

1. Lees `bc-upgrade-patterns.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin/knowledge ./.claude/plugins/bc-claude-plugin/knowledge ~/.local/share/claude/plugins/bc-claude-plugin/knowledge ~/code/bc-claude-plugin/knowledge -name "bc-upgrade-patterns.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   voor UpgradeTag, DataTransfer, trigger volgorde.
2. Lees `al-guidelines.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin/knowledge ./.claude/plugins/bc-claude-plugin/knowledge ~/.local/share/claude/plugins/bc-claude-plugin/knowledge ~/code/bc-claude-plugin/knowledge -name "al-guidelines.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   voor naamgeving en ObsoleteState lifecycle.
3. Lees `bc-version-matrix.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin/knowledge ./.claude/plugins/bc-claude-plugin/knowledge ~/.local/share/claude/plugins/bc-claude-plugin/knowledge ~/code/bc-claude-plugin/knowledge -name "bc-version-matrix.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   → DataTransfer vereist BC 20+.
4. Lees `app.json` → huidige versie, vorige versie (als beschikbaar).

### Stap 1 — Analyseer wijzigingen

Vergelijk huidige code met git history:

```bash
# Gewijzigde tabel-bestanden
git diff main --name-only -- '*.Table.al' '*.TableExt.al'
```

Per gewijzigd tabelbestand, detecteer:
- **Verwijderde velden** → vereist data-migratie vóór removal
- **Hernoemde velden** → breaking change, vereist nieuw veld + migratie
- **Type-wijzigingen** → breaking change, vereist nieuw veld + migratie
- **Nieuwe ObsoleteState = Pending** → geen migratie nodig, maar documenteren
- **ObsoleteState Pending → Removed** → verifieer dat migratie al gedraaid is
- **Nieuwe verplichte velden** → default waarde nodig voor bestaande records

### Stap 2 — Rapporteer analyse

```
## Upgrade Analyse

### Breaking Changes (actie vereist)
- Veld "Old Email" (tabel "MYAPP Customer Ext"): type gewijzigd Text[50] → Text[100]
  → Maak nieuw veld, migreer data, markeer oud als Pending

### Data Migratie Nodig
- Veld "New Status" toegevoegd (tabel "MYAPP Header"): Default waarde instellen voor bestaande records

### Obsolete Lifecycle
- Veld "Legacy Code" gemarkeerd als Pending — geen actie nodig nu
- Veld "Old Field" was Pending → nu Removed — verifieer dat migratie code bestaat

### Geen Actie Nodig
- Nieuwe velden zonder default: OK (NULL is acceptabel)
```

### Stap 3 — Genereer upgrade codeunit (bij --generate)

Per migratie-scenario:

```al
codeunit <ID> "<PREFIX> Upgrade v<version>"
{
    Subtype = Upgrade;
    Access = Internal;

    trigger OnUpgradePerCompany()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if not UpgradeTag.HasUpgradeTag(GetMigrateTag()) then begin
            MigrateData();
            UpgradeTag.SetUpgradeTag(GetMigrateTag());
        end;
    end;

    local procedure MigrateData()
    begin
        // DataTransfer voor groot volume
        // of record loop voor transformaties
    end;

    local procedure GetMigrateTag(): Code[250]
    begin
        exit('<PREFIX>-<ID>-<Beschrijving>-<Datum>');
    end;
}
```

Genereer ook de install codeunit (of update bestaande):

```al
codeunit <ID> "<PREFIX> Install"
{
    Subtype = Install;
    Access = Internal;

    trigger OnInstallAppPerCompany()
    begin
        RegisterAllUpgradeTags();
    end;

    local procedure RegisterAllUpgradeTags()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        // Alle tags registreren zodat verse installaties migraties skippen
    end;
}
```

### Stap 4 — Breaking change waarschuwingen

Als AppSourceCop actief is (check `AppSourceCop.json`):
- Waarschuw voor AS0001 (tabel verwijderd), AS0002 (veld verwijderd), etc.
- Adviseer obsolete lifecycle als die niet gevolgd wordt

## Regels

- ALTIJD UpgradeTag pattern (nooit versiechecks)
- ALTIJD install codeunit bijwerken met nieuwe tags
- DataTransfer voor >300K rijen (check tabelgrootte als mogelijk)
- `Modify(false)` in upgrade loops (geen triggers)
- `Session.GetExecutionContext()` check voor externe calls
- Lees `bc-upgrade-patterns.md` uit de knowledge/ map van de bc-claude-plugin.
    Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin/knowledge ./.claude/plugins/bc-claude-plugin/knowledge ~/.local/share/claude/plugins/bc-claude-plugin/knowledge ~/code/bc-claude-plugin/knowledge -name "bc-upgrade-patterns.md" 2>/dev/null | head -1`
    Als het niet gevonden wordt, meld dit en vraag of de plugin correct geïnstalleerd is.
   voor alle patronen
