# BC Publisher Events Reference

Catalogus van veelgebruikte BC publisher events per domein. Canonical source: [microsoft/ALAppExtensions](https://github.com/microsoft/ALAppExtensions).

---

## Sales

### Sales-Post (Codeunit 80)

```al
// Vóór het boeken van een verkoopdocument
[IntegrationEvent(false, false)]
local procedure OnBeforePostSalesDoc(var SalesHeader: Record "Sales Header"; CommitIsSuppressed: Boolean; PreviewMode: Boolean; var HideProgressWindow: Boolean; var IsHandled: Boolean)

// Na het boeken — geboekt documentnr beschikbaar
[IntegrationEvent(false, false)]
local procedure OnAfterPostSalesDoc(var SalesHeader: Record "Sales Header"; var SalesShipmentHeader: Record "Sales Shipment Header"; var SalesInvoiceHeader: Record "Sales Invoice Header"; var SalesCrMemoHeader: Record "Sales Cr.Memo Header"; CommitIsSuppressed: Boolean)

// Vóór het boeken van een individuele Sales Line
[IntegrationEvent(false, false)]
local procedure OnBeforePostSalesLine(var SalesHeader: Record "Sales Header"; var SalesLine: Record "Sales Line"; CommitIsSuppressed: Boolean)

// Na het boeken van een individuele Sales Line
[IntegrationEvent(false, false)]
local procedure OnAfterPostSalesLine(var SalesHeader: Record "Sales Header"; var SalesLine: Record "Sales Line"; CommitIsSuppressed: Boolean)
```

**Typisch gebruik:** Extra validaties, custom ledger entries, notificaties, integratie met externe systemen.

**Valkuil:** `IsHandled` pattern — als je `IsHandled := true` zet, skip je de standaard posting-logica. Doe dit alleen als je het volledige posting-proces vervangt.

### Release Sales Document (Codeunit 414)

```al
[IntegrationEvent(false, false)]
local procedure OnBeforeReleaseSalesDoc(var SalesHeader: Record "Sales Header"; PreviewMode: Boolean; var IsHandled: Boolean)

[IntegrationEvent(false, false)]
local procedure OnAfterReleaseSalesDoc(var SalesHeader: Record "Sales Header"; PreviewMode: Boolean; LinesWereModified: Boolean)

[IntegrationEvent(false, false)]
local procedure OnBeforeReopenSalesDoc(var SalesHeader: Record "Sales Header"; PreviewMode: Boolean; var IsHandled: Boolean)
```

**Typisch gebruik:** Extra checks bij release (voorraadcontrole, kredietlimiet), blokkeren van reopen.

### Sales-Post Prepayments (Codeunit 442)

```al
[IntegrationEvent(false, false)]
local procedure OnBeforePostPrepayments(var SalesHeader: Record "Sales Header"; DocumentType: Option; CommitIsSuppressed: Boolean)
```

---

## Purchase

### Purch.-Post (Codeunit 90)

```al
[IntegrationEvent(false, false)]
local procedure OnBeforePostPurchaseDoc(var PurchaseHeader: Record "Purchase Header"; PreviewMode: Boolean; CommitIsSuppressed: Boolean; var HideProgressWindow: Boolean; var IsHandled: Boolean)

[IntegrationEvent(false, false)]
local procedure OnAfterPostPurchaseDoc(var PurchaseHeader: Record "Purchase Header"; var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line"; PurchRcpHdrNo: Code[20]; RetShptHdrNo: Code[20]; PurchInvHdrNo: Code[20]; PurchCrMemoHdrNo: Code[20])

[IntegrationEvent(false, false)]
local procedure OnBeforePostPurchaseLine(var PurchaseHeader: Record "Purchase Header"; var PurchaseLine: Record "Purchase Line"; CommitIsSuppressed: Boolean)
```

### Release Purchase Document (Codeunit 415)

```al
[IntegrationEvent(false, false)]
local procedure OnBeforeReleasePurchaseDoc(var PurchaseHeader: Record "Purchase Header"; PreviewMode: Boolean; var IsHandled: Boolean)

[IntegrationEvent(false, false)]
local procedure OnAfterReleasePurchaseDoc(var PurchaseHeader: Record "Purchase Header"; PreviewMode: Boolean; LinesWereModified: Boolean)
```

---

## Finance

### Gen. Jnl.-Post Line (Codeunit 12)

```al
// Hoofd event voor elke journaalregel die geboekt wordt
[IntegrationEvent(false, false)]
local procedure OnBeforePostGenJnlLine(var GenJournalLine: Record "Gen. Journal Line"; Balancing: Boolean; var IsHandled: Boolean)

[IntegrationEvent(false, false)]
local procedure OnAfterPostGenJnlLine(var GenJournalLine: Record "Gen. Journal Line"; Balancing: Boolean)

// Na aanmaken G/L Entry
[IntegrationEvent(false, false)]
local procedure OnAfterInsertGLEntry(var GLEntry: Record "G/L Entry"; var GenJournalLine: Record "Gen. Journal Line")

// Na aanmaken Customer Ledger Entry
[IntegrationEvent(false, false)]
local procedure OnAfterCustLedgEntryInsert(var CustLedgerEntry: Record "Cust. Ledger Entry"; GenJournalLine: Record "Gen. Journal Line")

// Na aanmaken Vendor Ledger Entry
[IntegrationEvent(false, false)]
local procedure OnAfterVendLedgEntryInsert(var VendorLedgerEntry: Record "Vendor Ledger Entry"; GenJournalLine: Record "Gen. Journal Line")
```

**Typisch gebruik:** Custom dimensies toevoegen, extra ledger entries aanmaken, audit logging.

**Valkuil:** Nooit `Commit` aanroepen in deze subscribers — de posting-transactie loopt nog.

### Gen. Jnl.-Check Line (Codeunit 11)

```al
[IntegrationEvent(false, false)]
local procedure OnAfterCheckGenJnlLine(var GenJournalLine: Record "Gen. Journal Line")
```

---

## Inventory

### Item Jnl.-Post Line (Codeunit 22)

```al
[IntegrationEvent(false, false)]
local procedure OnBeforePostItemJnlLine(var ItemJournalLine: Record "Item Journal Line"; CalledFromAdjustment: Boolean; CalledFromInvtPutawayPick: Boolean; var IsHandled: Boolean)

[IntegrationEvent(false, false)]
local procedure OnAfterPostItemJnlLine(var ItemJournalLine: Record "Item Journal Line"; ItemLedgerEntry: Record "Item Ledger Entry")

// Na aanmaken Item Ledger Entry
[IntegrationEvent(false, false)]
local procedure OnAfterInsertItemLedgEntry(var ItemLedgerEntry: Record "Item Ledger Entry"; ItemJournalLine: Record "Item Journal Line")
```

### Reservation Management (Codeunit 99000845)

```al
[IntegrationEvent(false, false)]
local procedure OnBeforeAutoReserve(var ReservationEntry: Record "Reservation Entry"; var FullAutoReservation: Boolean; var IsHandled: Boolean)
```

---

## Warehouse

### Whse.-Post Shipment (Codeunit 5763)

```al
[IntegrationEvent(false, false)]
local procedure OnBeforePostedWhseShptHeaderInsert(var PostedWhseShipmentHeader: Record "Posted Whse. Shipment Header"; WarehouseShipmentHeader: Record "Warehouse Shipment Header")
```

### Whse.-Post Receipt (Codeunit 5760)

```al
[IntegrationEvent(false, false)]
local procedure OnBeforePostedWhseRcptHeaderInsert(var PostedWhseReceiptHeader: Record "Posted Whse. Receipt Header"; WarehouseReceiptHeader: Record "Warehouse Receipt Header")
```

---

## Document Approval

### Approvals Mgmt. (Codeunit 1535)

```al
[IntegrationEvent(false, false)]
local procedure OnSendSalesDocForApproval(var SalesHeader: Record "Sales Header")

[IntegrationEvent(false, false)]
local procedure OnSendPurchaseDocForApproval(var PurchaseHeader: Record "Purchase Header")

[IntegrationEvent(false, false)]
local procedure OnCancelSalesApprovalRequest(var SalesHeader: Record "Sales Header")
```

---

## Table Trigger Events

Automatisch beschikbaar voor elke tabel — subscriber-registratie:

```al
// Insert
[EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnBeforeInsertEvent', '', false, false)]
local procedure HandleSalesHeaderOnBeforeInsert(var Rec: Record "Sales Header"; RunTrigger: Boolean)

// Modify
[EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnBeforeModifyEvent', '', false, false)]
local procedure HandleSalesHeaderOnBeforeModify(var Rec: Record "Sales Header"; var xRec: Record "Sales Header"; RunTrigger: Boolean)

// Delete
[EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnBeforeDeleteEvent', '', false, false)]
local procedure HandleSalesHeaderOnBeforeDelete(var Rec: Record "Sales Header"; RunTrigger: Boolean)

// Validate (per veld)
[EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnAfterValidateEvent', 'Sell-to Customer No.', false, false)]
local procedure HandleAfterValidateSellToCustomer(var Rec: Record "Sales Header"; var xRec: Record "Sales Header"; CurrFieldNo: Integer)
```

**Valkuil:** Table events forceren row-by-row bij `ModifyAll`/`DeleteAll`. Vermijd in performance-kritieke paden.

---

## Subscriber Best Practices

1. **Eén subscriber codeunit per feature-area** — niet alles in één grote codeunit
2. **Subscriber codeunit naam:** `"MYAPP Sales Event Subscr."` (max 30 chars)
3. **Geen `Commit`** in subscribers — de caller bepaalt de transactie
4. **`var` parameters:** wijzig `Rec` direct, maak geen kopie tenzij je de originele waarde nodig hebt
5. **`IsHandled` pattern:** alleen `true` zetten als je de standaard logica volledig vervangt
6. **Binding:** `false, false` voor beide parameters (tenzij je Isolated binding nodig hebt)

### IsHandled Pattern

```al
[EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforePostSalesDoc', '', false, false)]
local procedure HandleOnBeforePostSalesDoc(var SalesHeader: Record "Sales Header"; var IsHandled: Boolean)
begin
    if IsHandled then
        exit; // andere subscriber heeft het al afgehandeld

    if not MyCustomValidation(SalesHeader) then
        Error(MyValidationFailedErr);

    // IsHandled NIET op true zetten — we voegen alleen validatie toe
end;
```
