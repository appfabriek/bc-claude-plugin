# BC Permissions & Entitlements

Patronen voor permission sets en entitlements in BC extensions.

---

## PermissionSet Object

```al
permissionset 50100 "MYAPP - Admin"
{
    Assignable = true;
    Caption = 'MYAPP Administrator';

    IncludedPermissionSets = "MYAPP - Basic";

    Permissions =
        tabledata "MYAPP Setup" = RIMD,
        tabledata "MYAPP Log Entry" = RD,
        table "MYAPP Setup" = X,
        page "MYAPP Setup Card" = X,
        codeunit "MYAPP Management" = X,
        report "MYAPP Sales Report" = X,
        query "MYAPP Top Items" = X;
}

permissionset 50101 "MYAPP - Basic"
{
    Assignable = true;
    Caption = 'MYAPP Basic User';

    Permissions =
        tabledata "MYAPP Header" = RIMD,
        tabledata "MYAPP Line" = RIMD,
        tabledata "MYAPP Setup" = R,
        page "MYAPP Document List" = X,
        page "MYAPP Document Card" = X;
}
```

### Permission Codes

| Code | Betekenis | Beschrijving |
|------|-----------|-------------|
| `R` | Read | Records lezen |
| `I` | Insert | Nieuwe records aanmaken |
| `M` | Modify | Bestaande records wijzigen |
| `D` | Delete | Records verwijderen |
| `X` | Execute | Object uitvoeren (codeunit, page, report) |

### Indirect vs Direct

```al
Permissions =
    tabledata "MYAPP My Table" = RIMD,   // Direct — user heeft recht
    tabledata "G/L Entry" = rim;          // Indirect (lowercase) — alleen via code
```

Indirect permissions: user kan de tabel niet direct openen, maar code die hij uitvoert mag dat wel.

---

## PermissionSet Extension

```al
permissionsetextension 50100 "MYAPP Extend Base" extends "D365 BASIC"
{
    Permissions =
        tabledata "MYAPP Header" = RIMD,
        tabledata "MYAPP Line" = RIMD;
}
```

- Extensions zijn **alleen additief** — je kunt geen rechten verwijderen
- Gebruik voor integratie met standaard BC permission sets

---

## Entitlement Object (AppSource)

```al
entitlement "MYAPP Premium"
{
    Type = PerUserServicePlan;
    Id = '00000000-0000-0000-0000-000000000001'; // Dynamics 365 Business Central Premium

    ObjectEntitlements =
        "MYAPP - Admin",
        "MYAPP - Basic";
}

entitlement "MYAPP Essential"
{
    Type = PerUserServicePlan;
    Id = '00000000-0000-0000-0000-000000000002'; // Dynamics 365 Business Central Essential

    ObjectEntitlements =
        "MYAPP - Basic";
}
```

### Service Plan IDs

| Plan | GUID |
|------|------|
| BC Premium | `8e9002c0-a1d8-4465-b952-817d2948e6e2` |
| BC Essential | `920656a2-7dd8-4c83-97b6-a356414dbd36` |
| BC Team Member | `d9a6391b-8970-4976-bd94-5f205007c8d8` |
| BC Device | `100e1865-35d4-4463-aaff-d38eee3a1116` |
| Delegated Admin | `00000000-0000-0000-0000-000000000007` |

---

## Minimal Permission Principe

### Strategie

1. **Admin set:** RIMD op alle eigen tabellen + setup
2. **User set:** RIMD op document-tabellen, R op setup, geen delete op log
3. **Read-only set:** R op alle eigen tabellen

### Base Table Permissions

Als je extensie base-tabellen leest/schrijft, voeg indirect permissions toe:

```al
permissionset 50101 "MYAPP - Basic"
{
    Permissions =
        // Eigen tabellen
        tabledata "MYAPP Header" = RIMD,
        // Base tabellen (indirect)
        tabledata Customer = r,
        tabledata "Sales Header" = rim,
        tabledata "Sales Line" = rim;
}
```

---

## Permission Set Naming

| Patroon | Voorbeeld | Gebruik |
|---------|-----------|---------|
| `APP - Role` | `"MYAPP - Admin"` | Toewijsbaar aan gebruikers |
| `APP - Objects` | `"MYAPP - Objects"` | Niet-toewijsbaar, technisch |

- Assignable names: max **20 tekens**
- Non-assignable names: max **30 tekens**
- Prefix met app-naam om conflicten te voorkomen

---

## Audit Checklist

- [ ] Elk object in het project heeft een permission entry
- [ ] Alle tabledata permissions kloppen (R/I/M/D per tabel)
- [ ] Base-tabel permissions zijn indirect (lowercase)
- [ ] Setup-tabellen: R voor users, RIMD voor admins
- [ ] Log-tabellen: R voor users, RD voor admins (geen I/M)
- [ ] Entitlements dekken alle permission sets
- [ ] Entitlement plan IDs kloppen voor de doellicenties
- [ ] Geen `Assignable = true` op technische/interne permission sets
