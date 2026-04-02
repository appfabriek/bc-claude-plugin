# AL Static Analysis Toolchain

## De vier Microsoft analyzers

| Analyzer | Doel | Inschakelen voor |
|----------|------|------------------|
| CodeCop | Officiële AL coding guidelines | Altijd |
| UICop | Web client UI regels | Altijd |
| AppSourceCop | AppSource submission compliance | ISV / AppSource apps |
| PerTenantExtensionCop | PTE veiligheid en upgradeabiliteit | Maatwerk / PTE |

Nooit AppSourceCop én PerTenantExtensionCop tegelijk — ze hebben conflicterende regels. Aanbeveling: gebruik AppSourceCop ook voor PTEs om toekomstbestendig te zijn.

### settings.json

```json
{
    "al.enableCodeAnalysis": true,
    "al.codeAnalyzers": [
        "${CodeCop}",
        "${UICop}",
        "${AppSourceCop}"
    ]
}
```

### AppSourceCop.json

```json
{
    "mandatoryAffixes": ["ABC"],
    "publisher": "MijnBedrijf",
    "name": "MijnApp",
    "version": "1.0.0.0"
}
```

---

## ALCops (Community Linter)

LinterCop (Stefan Maron) wordt read-only in 2026. Opvolger: **ALCops** (Arthur van der Voort), v0.5.0 heeft ~95% van LinterCop regels gemigreerd.

### Toevoegen in AL-Go

```json
{
    "customCodeCops": [
        "https://github.com/ALCops/ALCops/releases/latest/download/ALCops.dll"
    ]
}
```

### Belangrijke regels

| Regel | Beschrijving |
|-------|-------------|
| LC0001 | FlowFields niet editable |
| LC0005 | `Commit()` vereist justification comment |
| LC0008 | Geen object ID in properties of variabelendeclaraties |
| LC0009 | `DrillDownPageId` en `LookupPageId` verplicht als tabel in list page |
| LC0015 | Casing van variabelgebruik moet matchen met definitie |
| LC0020 | `DataPerCompany` property verplicht op alle tabellen |
| LC0025 | Filter operators niet gebruiken in `SetRange` |
| LC0055 | Cognitieve complexiteit waarschuwing (≥8 cyclomatic) |

---

## ruleset.json

Customiseer welke regels errors/warnings/info/hidden zijn:

```json
{
    "name": "Project Ruleset",
    "rules": [
        { "id": "AA0137", "action": "None", "justification": "Allowed: unused vars in test code" },
        { "id": "LC0005", "action": "Error", "justification": "Commit must always be justified" }
    ]
}
```

Koppelen in app.json: `"ruleSetPath": ".vscode/project.ruleset.json"`

---

## Namespaces (BC22+, verplicht voor AppSource BC26+)

Minimaal twee niveaus:

```al
namespace MijnBedrijf.MijnApp.Sales;

table 50100 "Verkooporder Header ABC"
{
    // Affix in objectnaam nog steeds verplicht buiten topniveau namespace
}
```

Topniveau namespace = registered affix → objectnaam affix mag wegvallen (AppSourceCop AS0011).

---

## Conditionele Compilatie (#if CLEAN)

Patroon voor obsolete code cleanup over versies:

```al
#if not CLEAN27
[Obsolete('Gebruik NewProc() i.p.v. OldProc()', '27.0')]
procedure OldProc()
begin
    NewProc();
end;
#endif

procedure NewProc()
begin
    // nieuwe implementatie
end;
```

AL-Go: `"cleanMajorVersion": 27` in AL-Go-Settings.json activeert `CLEAN27` symbol.
