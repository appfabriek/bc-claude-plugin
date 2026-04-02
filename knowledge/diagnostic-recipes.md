# Diagnostic Recipes

Bewezen AL-snippets voor `/diagnose`. Elke snippet is de body van een `Execute(var pCduResult: Codeunit "Diagnostic Result")` procedure.

---

## Job Queue — Actieve jobs

```al
    var
        JobQueueEntry: Record "Job Queue Entry";
        ResultArray: JsonArray;
        ResultObject: JsonObject;
    begin
        JobQueueEntry.SetLoadFields(ID, Description, "Object Type to Run", "Object ID to Run", Status, "Recurring Job", "Earliest Start Date/Time");
        JobQueueEntry.SetFilter(Status, '%1|%2', JobQueueEntry.Status::Ready, JobQueueEntry.Status::"In Process");
        if JobQueueEntry.FindSet() then
            repeat
                Clear(ResultObject);
                ResultObject.Add('id', Format(JobQueueEntry.ID));
                ResultObject.Add('description', JobQueueEntry.Description);
                ResultObject.Add('objectType', Format(JobQueueEntry."Object Type to Run"));
                ResultObject.Add('objectId', JobQueueEntry."Object ID to Run");
                ResultObject.Add('status', Format(JobQueueEntry.Status));
                ResultObject.Add('recurring', JobQueueEntry."Recurring Job");
                ResultObject.Add('earliestStart', Format(JobQueueEntry."Earliest Start Date/Time"));
                ResultArray.Add(ResultObject);
            until JobQueueEntry.Next() = 0;
        pCduResult.SetArray('activeJobs', ResultArray);
        pCduResult.SetInteger('count', ResultArray.Count());
    end;
```

---

## Job Queue — Gefaalde jobs

```al
    var
        JobQueueEntry: Record "Job Queue Entry";
        ResultArray: JsonArray;
        ResultObject: JsonObject;
    begin
        JobQueueEntry.SetLoadFields(ID, Description, "Object ID to Run", "Error Message", "Earliest Start Date/Time");
        JobQueueEntry.SetRange(Status, JobQueueEntry.Status::Error);
        if JobQueueEntry.FindSet() then
            repeat
                Clear(ResultObject);
                ResultObject.Add('id', Format(JobQueueEntry.ID));
                ResultObject.Add('description', JobQueueEntry.Description);
                ResultObject.Add('objectId', JobQueueEntry."Object ID to Run");
                ResultObject.Add('errorMessage', JobQueueEntry."Error Message");
                ResultObject.Add('earliestStart', Format(JobQueueEntry."Earliest Start Date/Time"));
                ResultArray.Add(ResultObject);
            until JobQueueEntry.Next() = 0;
        pCduResult.SetArray('failedJobs', ResultArray);
        pCduResult.SetInteger('count', ResultArray.Count());
    end;
```

---

## Job Queue — Recente log entries

```al
    var
        JobQueueLogEntry: Record "Job Queue Log Entry";
        ResultArray: JsonArray;
        ResultObject: JsonObject;
        Counter: Integer;
    begin
        JobQueueLogEntry.SetLoadFields("Object ID to Run", Status, "Start Date/Time", "End Date/Time", "Error Message");
        JobQueueLogEntry.SetCurrentKey("Start Date/Time");
        JobQueueLogEntry.Ascending(false);
        if JobQueueLogEntry.FindSet() then
            repeat
                Counter += 1;
                Clear(ResultObject);
                ResultObject.Add('objectId', JobQueueLogEntry."Object ID to Run");
                ResultObject.Add('status', Format(JobQueueLogEntry.Status));
                ResultObject.Add('startDateTime', Format(JobQueueLogEntry."Start Date/Time"));
                ResultObject.Add('endDateTime', Format(JobQueueLogEntry."End Date/Time"));
                if JobQueueLogEntry.Status = JobQueueLogEntry.Status::Error then
                    ResultObject.Add('errorMessage', JobQueueLogEntry."Error Message");
                ResultArray.Add(ResultObject);
            until (JobQueueLogEntry.Next() = 0) or (Counter >= 50);
        pCduResult.SetArray('recentLogs', ResultArray);
        pCduResult.SetInteger('count', ResultArray.Count());
    end;
```

---

## Installed Extensions

Gebruik `ModuleInfo` via `NavApp.GetModuleInfo()` of lees de virtuele tabel 2000000153 ("NAV App Installed App") via `RecordRef`:

```al
    var
        InstalledApp: RecordRef;
        FieldName: FieldRef;
        FieldPublisher: FieldRef;
        FieldMajor: FieldRef;
        FieldMinor: FieldRef;
        FieldBuild: FieldRef;
        FieldRevision: FieldRef;
        ResultArray: JsonArray;
        ResultObject: JsonObject;
    begin
        // Tabel 2000000153 = NAV App Installed App (virtuele tabel)
        InstalledApp.Open(2000000153);
        FieldName := InstalledApp.Field(3);       // Name
        FieldPublisher := InstalledApp.Field(4);   // Publisher
        FieldMajor := InstalledApp.Field(6);       // Version Major
        FieldMinor := InstalledApp.Field(7);       // Version Minor
        FieldBuild := InstalledApp.Field(8);       // Version Build
        FieldRevision := InstalledApp.Field(9);    // Version Revision
        if InstalledApp.FindSet() then
            repeat
                Clear(ResultObject);
                ResultObject.Add('name', Format(FieldName.Value));
                ResultObject.Add('publisher', Format(FieldPublisher.Value));
                ResultObject.Add('version', StrSubstNo('%1.%2.%3.%4',
                    FieldMajor.Value, FieldMinor.Value, FieldBuild.Value, FieldRevision.Value));
                ResultArray.Add(ResultObject);
            until InstalledApp.Next() = 0;
        pCduResult.SetArray('extensions', ResultArray);
        pCduResult.SetInteger('count', ResultArray.Count());
    end;
```

---

## Open Sales Orders — Telling

```al
    var
        SalesHeader: Record "Sales Header";
    begin
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.SetRange(Status, SalesHeader.Status::Open);
        pCduResult.SetInteger('openSalesOrders', SalesHeader.Count());

        SalesHeader.SetRange(Status, SalesHeader.Status::Released);
        pCduResult.SetInteger('releasedSalesOrders', SalesHeader.Count());
    end;
```

---

## Open Purchase Orders — Telling

```al
    var
        PurchaseHeader: Record "Purchase Header";
    begin
        PurchaseHeader.SetRange("Document Type", PurchaseHeader."Document Type"::Order);
        PurchaseHeader.SetRange(Status, PurchaseHeader.Status::Open);
        pCduResult.SetInteger('openPurchaseOrders', PurchaseHeader.Count());

        PurchaseHeader.SetRange(Status, PurchaseHeader.Status::Released);
        pCduResult.SetInteger('releasedPurchaseOrders', PurchaseHeader.Count());
    end;
```

---

## Company Information

```al
    var
        CompanyInfo: Record "Company Information";
    begin
        CompanyInfo.Get();
        pCduResult.Set('companyName', CompanyInfo.Name);
        pCduResult.Set('vatNo', CompanyInfo."VAT Registration No.");
        pCduResult.Set('customIndicator', CompanyInfo."Custom System Indicator Text");
    end;
```

---

## Record Count — Willekeurige tabel

Pas tabelnummer aan (voorbeeld: Item = 27):

```al
    var
        RecRef: RecordRef;
    begin
        RecRef.Open(27); // 27 = Item
        pCduResult.SetInteger('recordCount', RecRef.Count());
        pCduResult.Set('tableName', RecRef.Caption);
        RecRef.Close();
    end;
```

---

## Customer Balances — Top 10

Let op: "Balance (LCY)" is een FlowField — je kunt er niet op sorteren met `SetCurrentKey`. Haal alle klanten met saldo op en sorteer in-memory:

```al
    var
        Customer: Record Customer;
        ResultArray: JsonArray;
        ResultObject: JsonObject;
        TopBalances: List of [Decimal];
        TopCustomers: Dictionary of [Decimal, Text];
        Balance: Decimal;
        CustomerInfo: Text;
        Counter: Integer;
    begin
        Customer.SetLoadFields("No.", Name);
        if Customer.FindSet() then
            repeat
                Customer.CalcFields("Balance (LCY)");
                if Customer."Balance (LCY)" > 0 then begin
                    // Bewaar als key-value (saldo -> info)
                    Clear(ResultObject);
                    ResultObject.Add('no', Customer."No.");
                    ResultObject.Add('name', Customer.Name);
                    ResultObject.Add('balance', Customer."Balance (LCY)");
                    ResultArray.Add(ResultObject);
                end;
            until Customer.Next() = 0;
        // Sorteer client-side niet mogelijk in AL, maar resultaat bevat alle klanten met saldo > 0
        // Beperk tot redelijk aantal als er veel klanten zijn
        pCduResult.SetArray('customers', ResultArray);
        pCduResult.SetInteger('count', ResultArray.Count());
    end;
```

---

## Error Messages — Recent

```al
    var
        ErrorMessage: Record "Error Message";
        ResultArray: JsonArray;
        ResultObject: JsonObject;
        Counter: Integer;
    begin
        ErrorMessage.SetLoadFields(ID, Message, "Context Record ID", "Created On");
        ErrorMessage.SetCurrentKey("Created On");
        ErrorMessage.Ascending(false);
        if ErrorMessage.FindSet() then
            repeat
                Counter += 1;
                Clear(ResultObject);
                ResultObject.Add('id', ErrorMessage.ID);
                ResultObject.Add('message', ErrorMessage.Message);
                ResultObject.Add('contextRecordId', Format(ErrorMessage."Context Record ID"));
                ResultObject.Add('createdOn', Format(ErrorMessage."Created On"));
                ResultArray.Add(ResultObject);
            until (ErrorMessage.Next() = 0) or (Counter >= 25);
        pCduResult.SetArray('errors', ResultArray);
        pCduResult.SetInteger('count', ResultArray.Count());
    end;
```

---

## Extensie-versie checken

```al
    var
        ModuleInfo: ModuleInfo;
        AppInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(ModuleInfo);
        pCduResult.Set('diagnosticAppId', Format(ModuleInfo.Id));
        pCduResult.Set('diagnosticAppVersion', Format(ModuleInfo.AppVersion));

        // Specifieke extensie opzoeken via AppId
        // Vervang de GUID door de werkelijke app ID
        if NavApp.GetModuleInfo('00000000-0000-0000-0000-000000000000', AppInfo) then begin
            pCduResult.Set('targetAppName', AppInfo.Name);
            pCduResult.Set('targetAppVersion', Format(AppInfo.AppVersion));
        end else
            pCduResult.Set('targetApp', 'not installed');
    end;
```

---

## Tips voor nieuwe diagnostics

- Gebruik `RecordRef` + `FieldRef` voor virtuele/systeem-tabellen (tabel > 2000000000)
- `RecordRef.SetFilter()` bestaat NIET — gebruik `FieldRef.SetFilter()`
- Errors worden automatisch opgevangen via TryFunction — geen error handling nodig
- Beperk resultaten met een counter om timeouts te voorkomen (max ~100 records)
- `pCduResult.Log('debug')` voor tussentijdse debug-output
- Gebruik `SetLoadFields` waar mogelijk voor performance
