# BC Test Patterns

Patronen voor het schrijven en uitvoeren van AL-testcodeunits.

---

## Test Codeunit Structuur

```al
codeunit 50150 "MYAPP Sales Order Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit Assert;
        LibrarySales: Codeunit "Library - Sales";
        LibraryRandom: Codeunit "Library - Random";
        IsInitialized: Boolean;

    local procedure Initialize()
    begin
        if IsInitialized then
            exit;
        // Eenmalige setup per test run
        IsInitialized := true;
    end;

    [Test]
    [HandlerFunctions('ConfirmHandler')]
    procedure PostSalesOrderCreatesGLEntry()
    var
        SalesHeader: Record "Sales Header";
        GLEntry: Record "G/L Entry";
        DocumentNo: Code[20];
    begin
        // GIVEN
        Initialize();
        CreateSalesOrderWithLine(SalesHeader);

        // WHEN
        DocumentNo := LibrarySales.PostSalesDocument(SalesHeader, true, true);

        // THEN
        GLEntry.SetRange("Document No.", DocumentNo);
        Assert.RecordIsNotEmpty(GLEntry);
    end;

    [ConfirmHandler]
    procedure ConfirmHandler(Question: Text[1024]; var Reply: Boolean)
    begin
        Reply := true;
    end;
}
```

---

## Given/When/Then Patroon

### GIVEN — Setup testdata

```al
local procedure CreateSalesOrderWithLine(var SalesHeader: Record "Sales Header")
var
    SalesLine: Record "Sales Line";
    Customer: Record Customer;
    Item: Record Item;
begin
    LibrarySales.CreateCustomer(Customer);
    LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");

    LibrarySales.CreateSalesLine(
        SalesLine, SalesHeader, SalesLine.Type::Item,
        LibraryRandom.RandText(20), LibraryRandom.RandInt(10));
end;
```

### WHEN — Voer de actie uit

Eén actie per test — het "moment" dat je test:
```al
DocumentNo := LibrarySales.PostSalesDocument(SalesHeader, true, true);
```

### THEN — Verifieer het resultaat

```al
// Record bestaat
Assert.RecordIsNotEmpty(GLEntry);

// Specifieke waarde
Assert.AreEqual(ExpectedAmount, GLEntry.Amount, 'Amount should match');

// Record bestaat niet
Assert.RecordIsEmpty(SalesHeader);

// Boolean
Assert.IsTrue(Result, 'Expected true');

// Error verwacht
asserterror MyCodeunit.Run();
Assert.ExpectedError('Expected error text');
```

---

## Handler Attributen

Handlers vangen UI-interacties op die normaal een test zouden blokkeren:

| Attribuut | Vangt op | Signature |
|-----------|----------|-----------|
| `[MessageHandler]` | `Message()` | `procedure MyHandler(Message: Text[1024])` |
| `[ConfirmHandler]` | `Confirm()` | `procedure MyHandler(Question: Text[1024]; var Reply: Boolean)` |
| `[StrMenuHandler]` | `StrMenu()` | `procedure MyHandler(Options: Text[1024]; var Choice: Integer; Instruction: Text[1024])` |
| `[PageHandler]` | `Page.Run()` | `procedure MyHandler(var Page: Page "My Page")` |
| `[ModalPageHandler]` | `Page.RunModal()` | `procedure MyHandler(var Page: Page "My Page"; var Response: Action)` |
| `[ReportHandler]` | `Report.Run()` | `procedure MyHandler(var Report: Report "My Report")` |
| `[SendNotificationHandler]` | `Notification.Send()` | `procedure MyHandler(var Notification: Notification): Boolean` |
| `[RecallNotificationHandler]` | `Notification.Recall()` | `procedure MyHandler(var Notification: Notification): Boolean` |
| `[HyperlinkHandler]` | `Hyperlink()` | `procedure MyHandler(Message: Text[1024])` |
| `[FilterPageHandler]` | `FilterPageBuilder.RunModal()` | `procedure MyHandler(var FilterPage: FilterPageBuilder)` |

Refereer handlers in test met `[HandlerFunctions('Handler1,Handler2')]`.

---

## Library Codeunits (Quick Reference)

| Codeunit | Gebruik |
|----------|---------|
| `Library - Sales` | `CreateCustomer`, `CreateSalesHeader`, `CreateSalesLine`, `PostSalesDocument` |
| `Library - Purchase` | `CreateVendor`, `CreatePurchaseHeader`, `CreatePurchaseLine`, `PostPurchaseDocument` |
| `Library - Inventory` | `CreateItem`, `CreateItemJournalLine`, `PostItemJournalLine` |
| `Library - ERM` | `CreateGenJournalLine`, `PostGeneralJnlLine`, `CreateGLAccount` |
| `Library - Random` | `RandInt`, `RandDec`, `RandText`, `RandDate` |
| `Library - Utility` | `GenerateGUID`, `GetGlobalNoSeriesCode` |
| `Library - Job` | `CreateJob`, `CreateJobTask`, `CreateJobPlanningLine` |
| `Library - Warehouse` | `CreateLocation`, `CreateWarehouseShipment` |
| `Library - Resource` | `CreateResource`, `CreateResourcePrice` |
| `Assert` | `AreEqual`, `AreNotEqual`, `IsTrue`, `IsFalse`, `RecordIsNotEmpty`, `RecordIsEmpty`, `ExpectedError` |

---

## TestPermissions

```al
codeunit 50151 "MYAPP Permission Tests"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    [Test]
    procedure UserCanReadCustomersWithBasicAccess()
    var
        Customer: Record Customer;
    begin
        // Assign minimal permission set
        LibraryLowerPermissions.SetO365BusFull();

        // This should work with basic permissions
        Customer.SetLoadFields("No.", Name);
        Assert.IsTrue(Customer.FindFirst(), 'Should be able to read customers');
    end;
}
```

| Waarde | Betekenis |
|--------|-----------|
| `Disabled` | Geen permissie-checks (standaard voor unit tests) |
| `NonRestrictive` | Brede rechten, test werkt bijna altijd |
| `Restrictive` | Minimale rechten — test moet expliciet permissies toewijzen |

---

## Veelgemaakte Fouten

| Fout | Oplossing |
|------|-----------|
| `Commit` in test | Verwijder — tests draaien in eigen transactie die automatisch teruggedraaid wordt |
| Database state leakage | Gebruik `Initialize()` patroon met `IsInitialized` vlag |
| Hardcoded record IDs | Gebruik Library codeunits om testdata aan te maken |
| Ontbrekende handler | Voeg `[HandlerFunctions('...')]` toe — anders hangt de test |
| Test hangt bij dialog | Er ontbreekt een handler; check welke UI-interactie niet afgevangen wordt |
| `asserterror` zonder `ExpectedError` | Altijd `Assert.ExpectedError(...)` combineren met `asserterror` |
| Test afhankelijk van volgorde | Elke `[Test]` moet onafhankelijk runnen — geen gedeelde state |

---

## Test Uitvoeren

### Via AL Test Runner page

In BC: zoek "Test Tool" (page 130401). Voer test codeunits toe en run.

### Via REST endpoint (dev server)

```bash
curl -sk -u "admin:password" \
  "https://host:7049/instance/dev/test?tenant=default&testCodeunit=50150" \
  -H "Accept: application/json"
```

### Via GitHub Actions

Gebruik `bc-diagnostic.yaml` workflow met test-specifieke AL code, of een dedicated test-workflow.
