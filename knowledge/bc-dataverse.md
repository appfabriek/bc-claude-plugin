# BC Dataverse Integration Patterns

Patronen voor Business Central ↔ Dataverse (CDS) integratie.

---

## Architectuur Overzicht

```
Business Central  ←→  Integration Table  ←→  Dataverse (CDS)
                        ↕
                  Coupling Record
               (BC Record ID ↔ CDS ID)
```

- **Integration Table:** BC-tabel die de Dataverse-entiteit spiegelt
- **Coupling:** Koppeling tussen BC record en CDS record via `CRM Integration Record`
- **Synch Job:** Job Queue Entry die synchronisatie uitvoert

---

## Integration Table

```al
table 50400 "MYAPP CDS Project"
{
    TableType = CDS;
    ExternalName = 'myapp_project';
    Description = 'Dataverse Project Entity';

    fields
    {
        field(1; ProjectId; Guid)
        {
            ExternalName = 'myapp_projectid';
            ExternalType = 'Uniqueidentifier';
            ExternalAccess = Insert;
            Description = 'Unique identifier';
        }
        field(2; Name; Text[200])
        {
            ExternalName = 'myapp_name';
            ExternalType = 'String';
            Description = 'Project name';
        }
        field(3; StatusCode; Option)
        {
            ExternalName = 'statuscode';
            ExternalType = 'Status';
            OptionMembers = ' ',Active,Inactive;
            OptionOrdinalValues = -1, 1, 2;
        }
        field(4; ModifiedOn; DateTime)
        {
            ExternalName = 'modifiedon';
            ExternalType = 'DateTime';
            ExternalAccess = Read;
        }
    }

    keys
    {
        key(PK; ProjectId) { Clustered = true; }
        key(Name; Name) { }
    }
}
```

### Verplichte Properties

- `TableType = CDS` — markeert als integration table
- `ExternalName` — exacte Dataverse tabel logical name
- `ExternalAccess` — `Full`, `Insert`, `Read`, `Modify` per veld
- Primary key: Guid-veld met `ExternalAccess = Insert`
- `ModifiedOn` veld (verplicht voor delta sync)

---

## Coupling Setup

### Integration Table Mapping

```al
codeunit 50401 "MYAPP CDS Setup"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDS Setup Defaults", 'OnGetCDSTableNo', '', false, false)]
    local procedure HandleOnGetCDSTableNo(BCTableNo: Integer; var CDSTableNo: Integer; var Handled: Boolean)
    begin
        if BCTableNo = Database::"MYAPP Project" then begin
            CDSTableNo := Database::"MYAPP CDS Project";
            Handled := true;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDS Setup Defaults", 'OnAfterResetConfiguration', '', false, false)]
    local procedure HandleOnAfterResetConfiguration(CDSConnectionSetup: Record "CDS Connection Setup")
    begin
        InsertIntegrationTableMapping();
    end;

    local procedure InsertIntegrationTableMapping()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        IntegrationTableMapping.Init();
        IntegrationTableMapping.Name := 'MYAPP-PROJECT';
        IntegrationTableMapping."Table ID" := Database::"MYAPP Project";
        IntegrationTableMapping."Integration Table ID" := Database::"MYAPP CDS Project";
        IntegrationTableMapping."Synch. Codeunit ID" := Codeunit::"CRM Integration Table Synch.";
        IntegrationTableMapping."Int. Tbl. UID Fld. Type" := IntegrationTableMapping."Int. Tbl. UID Fld. Type"::GUID;
        IntegrationTableMapping.Direction := IntegrationTableMapping.Direction::Bidirectional;
        IntegrationTableMapping.Insert();
    end;
}
```

---

## Field Mapping

```al
local procedure InsertFieldMappings()
var
    IntegrationFieldMapping: Record "Integration Field Mapping";
    MyProject: Record "MYAPP Project";
    CDSProject: Record "MYAPP CDS Project";
begin
    InsertFieldMapping(
        'MYAPP-PROJECT',
        MyProject.FieldNo(Name),
        CDSProject.FieldNo(Name),
        IntegrationFieldMapping.Direction::Bidirectional,
        '', true, false);

    InsertFieldMapping(
        'MYAPP-PROJECT',
        MyProject.FieldNo(Status),
        CDSProject.FieldNo(StatusCode),
        IntegrationFieldMapping.Direction::FromIntegrationTable,
        '', true, false);
end;

local procedure InsertFieldMapping(MappingName: Code[20]; BCFieldNo: Integer; CDSFieldNo: Integer;
    Direction: Option; TransformationRule: Text[50]; ValidateField: Boolean; ValidateIntField: Boolean)
var
    IntegrationFieldMapping: Record "Integration Field Mapping";
begin
    IntegrationFieldMapping.Init();
    IntegrationFieldMapping."Integration Table Mapping Name" := MappingName;
    IntegrationFieldMapping."Field No." := BCFieldNo;
    IntegrationFieldMapping."Integration Table Field No." := CDSFieldNo;
    IntegrationFieldMapping.Direction := Direction;
    IntegrationFieldMapping."Transformation Rule" := TransformationRule;
    IntegrationFieldMapping."Validate Field" := ValidateField;
    IntegrationFieldMapping."Validate Integration Table Fld." := ValidateIntField;
    IntegrationFieldMapping.Insert();
end;
```

---

## Synchronisatie

### Job Queue Setup

```al
local procedure CreateSynchJobQueueEntry(MappingName: Code[20]; IntervalMinutes: Integer)
var
    JobQueueEntry: Record "Job Queue Entry";
begin
    JobQueueEntry.Init();
    JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
    JobQueueEntry."Object ID to Run" := Codeunit::"Integration Synch. Job Runner";
    JobQueueEntry."Record ID to Process" := GetMappingRecordId(MappingName);
    JobQueueEntry."Run in User Session" := false;
    JobQueueEntry."No. of Minutes between Runs" := IntervalMinutes;
    JobQueueEntry.Description := 'Sync MYAPP Projects with Dataverse';
    JobQueueEntry.Insert(true);
end;
```

### Sync Direction

| Direction | Beschrijving |
|-----------|-------------|
| `ToIntegrationTable` | BC → Dataverse |
| `FromIntegrationTable` | Dataverse → BC |
| `Bidirectional` | Laatste wijziging wint |

---

## Veelgemaakte Fouten

| Fout | Oplossing |
|------|-----------|
| `ModifiedOn` veld ontbreekt | Verplicht voor delta sync — voeg toe aan integration table |
| Verkeerde `ExternalName` | Moet exact matchen met Dataverse logical name (lowercase) |
| Sync loopt vast | Check `Integration Synch. Job` entries voor foutmeldingen |
| Coupling niet aangemaakt | Gebruik `CRMIntegrationManagement.CreateNewRecordsInCRM()` |
| OptionOrdinalValues mismatch | Values moeten exact matchen met Dataverse option set |
| Geen `ExternalAccess = Insert` op PK | Primary key moet instelbaar zijn bij eerste sync |
| Bidirectional conflict | Stel conflict resolution in op mapping (BC wint of CDS wint) |
