# BC Report Development

## Layout Types

| Type | Wanneer | Gereedschap |
|------|---------|-------------|
| RDLC | Complexe pixel-perfect layouts | SQL Server Report Builder / RDLC Designer |
| Word | Klant-aanpasbare documenten | Microsoft Word + BC Word add-in |
| Excel | Data-export, analyse rapporten | Excel |
| Custom | External rendering (bv. PDF library) | AL code |

---

## Rendering Syntax (BC22+ / verplicht stijl)

De oude `RDLCLayout` / `WordLayout` properties zijn deprecated. Gebruik `rendering` sectie:

```al
report 50100 "MYAPP Sales Invoice"
{
    DefaultRenderingLayout = WordLayout;

    rendering
    {
        layout(WordLayout)
        {
            Type = Word;
            LayoutFile = 'layouts/SalesInvoice.docx';
            Caption = 'Sales Invoice (Word)';
        }
        layout(RDLCLayout)
        {
            Type = RDLC;
            LayoutFile = 'layouts/SalesInvoice.rdlc';
            Caption = 'Sales Invoice (RDLC)';
        }
    }

    dataset
    {
        dataitem(SalesInvoiceHeader; "Sales Invoice Header")
        {
            column(No_; "No.") { }
            column(BillToName; "Bill-to Name") { }
            column(PostingDate; "Posting Date") { }

            dataitem(SalesInvoiceLine; "Sales Invoice Line")
            {
                DataItemLink = "Document No." = field("No.");
                column(Description; Description) { }
                column(Quantity; Quantity) { }
                column(Amount; Amount) { }
            }
        }
    }

    requestpage
    {
        layout
        {
            area(Content)
            {
                group(Options)
                {
                    field(ShowDetails; ShowDetails)
                    {
                        Caption = 'Show Details';
                        ApplicationArea = All;
                    }
                }
            }
        }
    }

    var
        ShowDetails: Boolean;
}
```

**Code action in VS Code:** cursor op oude `RDLCLayout` property → "Convert to 'Rendering'"

---

## Word Layout Tips

- Nieuwe Word add-in taakpaneel (BC27+): Business Central tab → Add Data
- `WordMergeDataItem`: toont welk dataitem de Word merge drijft
- Sections in Word layout (BC25+): wissel marges/oriëntatie binnen één document
- `.rdlc` exporteren uit BC: hernoem naar `.rdl` voor Report Builder

---

## Report Extension

Voeg kolommen toe aan bestaand rapport:

```al
reportextension 50101 "MYAPP Sales Invoice Ext" extends "Standard Sales - Invoice"
{
    dataset
    {
        add(Header)
        {
            column(CustomField; "Custom Field ABC") { }
        }
    }

    rendering
    {
        layout(CustomWordLayout)
        {
            Type = Word;
            LayoutFile = 'layouts/ExtendedInvoice.docx';
        }
    }
}
```

---

## Processing-Only Reports

Geen layout, alleen logica:

```al
report 50102 "MYAPP Batch Process"
{
    ProcessingOnly = true;

    dataset
    {
        dataitem(SalesHeader; "Sales Header")
        {
            RequestFilterFields = "No.", "Posting Date";

            trigger OnAfterGetRecord()
            begin
                // batch logica per record
            end;
        }
    }

    trigger OnPostReport()
    begin
        Message(ProcessedMsg, RecordCount);
    end;

    var
        RecordCount: Integer;
        ProcessedMsg: Label '%1 records processed.';
}
```

---

## Report Layout Selectie via Code

Nieuw (BC22+) via Report Layouts tabel:

```al
var
    ReportLayoutSelection: Record "Report Layout Selection";
begin
    ReportLayoutSelection.SetRange("Report ID", Report::"MYAPP Sales Invoice");
    // manipuleer layout selectie
end;
```

---

## Dataset Best Practices

- Gebruik `RequestFilterFields` voor gebruikersfilters
- `DataItemLink` voor parent-child relaties
- `CalcFields` in `OnAfterGetRecord` voor FlowFields
- Beperk dataset-grootte met filters — grote datasets vertragen rendering
- Gebruik `MaxIteration` op dataitems als je een limiet wilt

---

## Veelgemaakte Fouten

| Fout | Oplossing |
|------|-----------|
| Layout pad niet gevonden | Relatief pad vanaf project root, niet absolute |
| Word merge velden missen | Regenereer Word layout via AL:Generate report layout |
| RDLC te groot | Splits in subreports of gebruik Excel layout |
| `Commit` in report trigger | Nooit — reports kunnen in preview-modus draaien |
| FlowField niet in dataset | Voeg `CalcFields` toe in `OnAfterGetRecord` trigger |
