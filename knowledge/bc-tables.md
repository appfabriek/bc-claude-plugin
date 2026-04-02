# BC Standard Tables Reference

Veelgebruikte Business Central-tabellen met tabelnummer en belangrijkste velden (veldnummer + naam). Bedoeld voor `/diagnose`, `/bc-query` en AL-ontwikkeling.

---

## Financieel

### 15 "G/L Account"
- 1 "No.", 2 "Name", 4 "Account Type" (0=Posting,1=Heading,2=Total,3=Begin-Total,4=End-Total), 31 "Balance", 38 "Blocked"

### 17 "G/L Entry"
- 1 "Entry No.", 3 "G/L Account No.", 4 "Posting Date", 5 "Document Type", 6 "Document No.", 13 "Amount", 17 "Debit Amount", 18 "Credit Amount", 52 "Source Code", 53 "Source Type"

### 21 "Cust. Ledger Entry"
- 1 "Entry No.", 3 "Customer No.", 4 "Posting Date", 5 "Document Type", 6 "Document No.", 13 "Amount", 17 "Remaining Amt. (LCY)", 43 "Remaining Amount", 82 "Open"

### 23 "Vendor"
- 1 "No.", 2 "Name", 58 "Balance (LCY)" (FlowField), 39 "Blocked", 54 "Gen. Bus. Posting Group", 74 "Country/Region Code"

### 25 "Vendor Ledger Entry"
- 1 "Entry No.", 3 "Vendor No.", 4 "Posting Date", 5 "Document Type", 6 "Document No.", 17 "Remaining Amt. (LCY)", 43 "Remaining Amount", 82 "Open"

### 93 "Vendor Posting Group"
- 1 "Code", 7 "Payables Account"

### 79 "Company Information"
- 1 "Primary Key", 2 "Name", 35 "VAT Registration No.", 107 "Custom System Indicator Text"

### 81 "Gen. Journal Line"
- 1 "Journal Template Name", 2 "Line No.", 3 "Account Type", 4 "Account No.", 5 "Posting Date", 13 "Amount", 51 "Journal Batch Name"

---

## Klanten

### 18 "Customer"
- 1 "No.", 2 "Name", 59 "Balance (LCY)" (FlowField), 39 "Blocked", 54 "Gen. Bus. Posting Group", 74 "Country/Region Code", 104 "E-Mail", 102 "Phone No."

### 379 "Detailed Cust. Ledg. Entry"
- 1 "Entry No.", 3 "Customer No.", 5 "Posting Date", 6 "Document Type", 7 "Document No.", 13 "Amount", 14 "Amount (LCY)"

### 380 "Detailed Vendor Ledg. Entry"
- 1 "Entry No.", 3 "Vendor No.", 5 "Posting Date", 6 "Document Type", 7 "Document No.", 13 "Amount", 14 "Amount (LCY)"

---

## Verkoop

### 36 "Sales Header"
- 1 "Document Type" (0=Quote,1=Order,2=Invoice,3=Credit Memo,4=Blanket Order,5=Return Order), 3 "No.", 2 "Sell-to Customer No.", 6 "Sell-to Customer Name", 20 "Posting Date", 27 "Status" (0=Open,1=Released,2=Pending Approval,3=Pending Prepayment), 79 "Sell-to Contact"

### 37 "Sales Line"
- 1 "Document Type", 3 "Document No.", 4 "Line No.", 5 "Type" (0=Space,1=G/L Account,2=Item,3=Resource,4=Fixed Asset,5=Charge), 6 "No.", 7 "Location Code", 11 "Description", 15 "Quantity", 22 "Unit Price", 29 "Amount"

### 110 "Sales Shipment Header"
- 3 "No.", 2 "Sell-to Customer No.", 20 "Posting Date", 60 "Order No."

### 112 "Sales Invoice Header"
- 3 "No.", 2 "Sell-to Customer No.", 20 "Posting Date", 60 "Order No."

### 114 "Sales Cr.Memo Header"
- 3 "No.", 2 "Sell-to Customer No.", 20 "Posting Date"

---

## Inkoop

### 38 "Purchase Header"
- 1 "Document Type" (0=Quote,1=Order,2=Invoice,3=Credit Memo,4=Blanket Order,5=Return Order), 3 "No.", 2 "Buy-from Vendor No.", 6 "Buy-from Vendor Name", 20 "Posting Date", 27 "Status" (0=Open,1=Released,2=Pending Approval,3=Pending Prepayment)

### 39 "Purchase Line"
- 1 "Document Type", 3 "Document No.", 4 "Line No.", 5 "Type", 6 "No.", 7 "Location Code", 11 "Description", 15 "Quantity", 22 "Direct Unit Cost", 29 "Amount"

### 120 "Purch. Rcpt. Header"
- 3 "No.", 2 "Buy-from Vendor No.", 20 "Posting Date", 60 "Order No."

### 122 "Purch. Inv. Header"
- 3 "No.", 2 "Buy-from Vendor No.", 20 "Posting Date"

---

## Voorraad / Items

### 27 "Item"
- 1 "No.", 3 "Description", 12 "Unit Cost", 20 "Unit Price", 41 "Inventory" (FlowField), 8 "Base Unit of Measure", 10 "Gen. Prod. Posting Group", 11 "Inventory Posting Group", 31 "Vendor No.", 99 "Item Tracking Code"

### 32 "Item Ledger Entry"
- 1 "Entry No.", 2 "Item No.", 3 "Posting Date", 5 "Entry Type" (0=Purchase,1=Sale,2=Positive Adj.,3=Negative Adj.,4=Transfer,5=Consumption,6=Output), 8 "Location Code", 12 "Quantity", 14 "Remaining Quantity", 29 "Source No."

### 5700 "Stockkeeping Unit"
- 1 "Item No.", 2 "Variant Code", 3 "Location Code"

---

## Locaties / Magazijn

### 14 "Location"
- 1 "Code", 2 "Name", 5730 "Require Receive", 5740 "Require Shipment", 5750 "Require Put-away", 5755 "Require Pick"

---

## Resources / Service

### 156 "Resource"
- 1 "No.", 2 "Type" (0=Person,1=Machine), 3 "Name", 22 "Unit Cost", 23 "Unit Price"

### 5900 "Service Header"
- 1 "Document Type", 3 "No.", 2 "Customer No.", 61 "Status" (0=Pending,1=In Process,2=Finished,3=On Hold)

### 5901 "Service Item Line"
- 1 "Document Type", 3 "Document No.", 4 "Line No."

### 5902 "Service Line"
- 1 "Document Type", 3 "Document No.", 4 "Line No.", 5 "Type", 6 "No.", 20 "Quantity"

### 5940 "Service Item"
- 1 "No.", 2 "Serial No.", 3 "Description", 4 "Customer No."

---

## Job Queue / Taakplanner

### 472 "Job Queue Entry"
- 1 "ID" (Guid), 3 "Object Type to Run" (1=Table,3=Report,5=Codeunit), 4 "Object ID to Run", 7 "Status" (0=Ready,1=In Process,2=Error,3=On Hold,4=Finished), 8 "Error Message", 14 "Earliest Start Date/Time", 15 "Expiration Date/Time", 19 "Recurring Job", 25 "Description"

### 474 "Job Queue Log Entry"
- 1 "Entry No.", 2 "ID" (ref naar Job Queue Entry), 5 "Object Type to Run", 6 "Object ID to Run", 8 "Status" (0=Success,1=In Process,2=Error), 10 "Error Message", 14 "Start Date/Time", 15 "End Date/Time"

---

## Error / Notificaties

### 700 "Error Message"
- 1 "ID", 2 "Error Type", 3 "Message", 5 "Context Record ID", 6 "Context Field No.", 8 "Table Number", 10 "Created On"

### 1511 "Notification Entry"
- 1 "ID", 2 "Type", 3 "Recipient User ID", 5 "Created By", 7 "Created Date-Time"

---

## Dimensies

### 348 "Dimension"
- 1 "Code", 2 "Name", 3 "Code Caption"

### 349 "Dimension Value"
- 1 "Dimension Code", 2 "Code", 3 "Name", 6 "Blocked"

### 480 "Dimension Set Entry"
- 1 "Dimension Set ID", 2 "Dimension Code", 3 "Dimension Value Code", 4 "Dimension Value ID"

---

## Systeem / Installatie

### 2000000004 "Company"
- 1 "Name"
- Gebruik `RecordRef.Open(2000000004)` om companies te lezen

### 2000000009 "Session"
- Virtual table — altijd via RecordRef:
```al
SessionRef.Open(2000000009);
```

### 2000000120 "NAV App Installed App"
- 1 "Package ID", 3 "Name", 4 "Publisher", 6 "Version Major", 7 "Version Minor", 8 "Version Build", 9 "Version Revision"
- Gebruik RecordRef voor deze virtual table

### 2000000160 "Table Metadata"
- Virtual table met objectmetadata. Via RecordRef.

---

## Veelgebruikte Enums / Option-waarden

### Document Type (Sales/Purchase Header)
- 0 = Quote
- 1 = Order
- 2 = Invoice
- 3 = Credit Memo
- 4 = Blanket Order
- 5 = Return Order

### Status (Sales/Purchase Header)
- 0 = Open
- 1 = Released
- 2 = Pending Approval
- 3 = Pending Prepayment

### Entry Type (Item Ledger Entry)
- 0 = Purchase
- 1 = Sale
- 2 = Positive Adj.
- 3 = Negative Adj.
- 4 = Transfer
- 5 = Consumption
- 6 = Output

### Job Queue Status
- 0 = Ready
- 1 = In Process
- 2 = Error
- 3 = On Hold
- 4 = Finished
