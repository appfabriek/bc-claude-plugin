# BC Upgrade Patterns

Patronen voor het schrijven van upgrade-codeunits bij schema-wijzigingen en data-migraties.

---

## Upgrade Codeunit Structuur

```al
codeunit 50300 "MYAPP Upgrade"
{
    Subtype = Upgrade;
    Access = Internal;

    trigger OnUpgradePerDatabase()
    begin
        // Database-brede migraties (zeldzaam)
    end;

    trigger OnUpgradePerCompany()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if not UpgradeTag.HasUpgradeTag(GetMoveDataTag()) then begin
            MoveOldFieldToNewField();
            UpgradeTag.SetUpgradeTag(GetMoveDataTag());
        end;

        if not UpgradeTag.HasUpgradeTag(GetCleanupTag()) then begin
            CleanupDeprecatedData();
            UpgradeTag.SetUpgradeTag(GetCleanupTag());
        end;
    end;

    local procedure GetMoveDataTag(): Code[250]
    begin
        exit('MYAPP-50100-MoveOldField-20240601');
    end;

    local procedure GetCleanupTag(): Code[250]
    begin
        exit('MYAPP-50101-CleanupData-20240601');
    end;
}
```

---

## UpgradeTag Pattern

**Altijd** UpgradeTag gebruiken — nooit versiechecks:

```al
// GOED
if UpgradeTag.HasUpgradeTag(GetMyTag()) then
    exit;
DoMigration();
UpgradeTag.SetUpgradeTag(GetMyTag());

// FOUT — breekt bij herinstallatie
if NavApp.GetCurrentModuleInfo().AppVersion < Version.Create(2, 0, 0, 0) then
    DoMigration();
```

### Tag Conventie

```
[PREFIX]-[ObjectID]-[Beschrijving]-[YYYYMMDD]

MYAPP-50100-MoveCustomerEmail-20240601
MYAPP-50200-AddDefaultDimension-20240615
MYAPP-50300-CleanupTempRecords-20240701
```

### Registreer Tags voor Nieuwe Installaties

Bij een verse installatie draait de upgrade codeunit NIET. Registreer tags in de install codeunit zodat bestaande migraties worden overgeslagen:

```al
codeunit 50301 "MYAPP Install"
{
    Subtype = Install;
    Access = Internal;

    trigger OnInstallAppPerCompany()
    begin
        SetAllUpgradeTags();
    end;

    local procedure SetAllUpgradeTags()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if not UpgradeTag.HasUpgradeTag(GetMoveDataTag()) then
            UpgradeTag.SetUpgradeTag(GetMoveDataTag());
        // ... herhaal voor alle tags
    end;
}
```

### Registreer Tags voor Nieuwe Companies

```al
[EventSubscriber(ObjectType::Codeunit, Codeunit::"Upgrade Tag", 'OnGetPerCompanyUpgradeTags', '', false, false)]
local procedure RegisterUpgradeTags(var PerCompanyUpgradeTags: List of [Code[250]])
begin
    PerCompanyUpgradeTags.Add(GetMoveDataTag());
    PerCompanyUpgradeTags.Add(GetCleanupTag());
end;
```

---

## PerDatabase vs PerCompany

| Trigger | Wanneer | Gebruik |
|---------|---------|---------|
| `OnUpgradePerDatabase` | Eén keer per database | Tabellen zonder company-scope, system setup |
| `OnUpgradePerCompany` | Eén keer per company | Standaard — de meeste migraties |

**Vuistregel:** gebruik `OnUpgradePerCompany` tenzij de tabel geen `CurrentCompany` filter heeft.

---

## Data Migratie Patronen

### Veld-naar-veld (klein volume)

```al
local procedure MoveOldFieldToNewField()
var
    MyTable: Record "MYAPP My Table";
begin
    MyTable.SetLoadFields("Old Field", "New Field");
    if MyTable.FindSet(true) then
        repeat
            if MyTable."New Field" = '' then begin
                MyTable."New Field" := MyTable."Old Field";
                MyTable.Modify();
            end;
        until MyTable.Next() = 0;
end;
```

### DataTransfer (groot volume, >300K rijen)

```al
local procedure MoveFieldBulk()
var
    DataTransfer: DataTransfer;
begin
    DataTransfer.SetTables(Database::"MYAPP My Table", Database::"MYAPP My Table");
    DataTransfer.AddFieldValue(MyTable.FieldNo("Old Field"), MyTable.FieldNo("New Field"));
    DataTransfer.CopyFields();
end;
```

**DataTransfer voordelen:**
- Direct SQL UPDATE — geen row-by-row
- Geen triggers/events
- Veel sneller voor grote tabellen

**DataTransfer beperkingen:**
- Geen transformaties (alleen kopie)
- Bron en doel kunnen dezelfde tabel zijn
- Geen filters — alle rijen worden bijgewerkt

### Tabel-naar-tabel

```al
local procedure MoveDataToNewTable()
var
    DataTransfer: DataTransfer;
begin
    DataTransfer.SetTables(Database::"MYAPP Old Table", Database::"MYAPP New Table");
    DataTransfer.AddFieldValue(
        OldTable.FieldNo("Customer No."),
        NewTable.FieldNo("Customer No."));
    DataTransfer.AddFieldValue(
        OldTable.FieldNo(Amount),
        NewTable.FieldNo(Amount));
    DataTransfer.CopyRows();
end;
```

---

## Obsolete Velden Afhandelen

### Stap 1 — Markeer als Pending (versie N)

```al
field(50100; "Old Field"; Text[100])
{
    ObsoleteState = Pending;
    ObsoleteReason = 'Replaced by "New Field" in table "MYAPP New Table". Will be removed in v3.0.';
    ObsoleteTag = '2.0';
}
```

### Stap 2 — Schrijf upgrade codeunit (versie N)

Migreer data van oud naar nieuw veld/tabel (zie patronen hierboven).

### Stap 3 — Markeer als Removed (versie N+1)

```al
field(50100; "Old Field"; Text[100])
{
    ObsoleteState = Removed;
    ObsoleteReason = 'Replaced by "New Field" in table "MYAPP New Table". Removed in v3.0.';
    ObsoleteTag = '3.0';
}
```

**Let op:** `Removed` verwijdert het DB-schema NIET. Het veld bestaat nog in de database maar is niet meer toegankelijk via AL.

---

## Execution Context

Skip externe calls tijdens upgrade:

```al
if Session.GetExecutionContext() <> ExecutionContext::Upgrade then begin
    SendEmailNotification(Customer);
    CallExternalApi(OrderData);
end;
```

Gebruik ook voor:
- Print jobs
- Job Queue scheduling
- Notification sending

---

## Trigger Volgorde

Bij upgrade draaien de triggers in deze volgorde:

1. `OnCheckPreconditionsPerDatabase`
2. `OnCheckPreconditionsPerCompany`
3. `OnUpgradePerDatabase`
4. `OnUpgradePerCompany`
5. `OnValidateUpgradePerDatabase`
6. `OnValidateUpgradePerCompany`

### Preconditions

```al
trigger OnCheckPreconditionsPerCompany()
var
    SetupTable: Record "MYAPP Setup";
begin
    if not SetupTable.Get() then
        Error('MYAPP Setup must exist before upgrading.');
end;
```

### Validation

```al
trigger OnValidateUpgradePerCompany()
var
    NewTable: Record "MYAPP New Table";
begin
    if NewTable.IsEmpty() then
        Error('Data migration to New Table failed — table is empty after upgrade.');
end;
```

---

## Veelgemaakte Valkuilen

| Valkuil | Oplossing |
|---------|-----------|
| Geen UpgradeTag → upgrade draait dubbel | Altijd UpgradeTag pattern gebruiken |
| Tags niet in Install codeunit | Nieuwe installaties skippen alle migraties niet |
| `Modify(true)` in upgrade loop | Triggers/events vuren — gebruik `Modify(false)` of `DataTransfer` |
| Vergeten `GetExecutionContext` check | Externe calls falen tijdens upgrade |
| Ontbrekende `NavApp.GetCurrentModuleInfo` | Gebruik UpgradeTag, niet versiechecks |
| DataTransfer met filters | DataTransfer ondersteunt geen filters — gebruik row-by-row als je filtert |
