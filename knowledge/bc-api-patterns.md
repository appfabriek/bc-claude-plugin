# BC API Patterns

Patronen voor het bouwen en consumeren van BC REST APIs.

---

## API Page v2.0 Structuur

```al
page 50100 "MYAPP Customer API"
{
    PageType = API;
    APIPublisher = 'mycompany';
    APIGroup = 'myapp';
    APIVersion = 'v2.0';
    EntityName = 'customer';
    EntitySetName = 'customers';
    SourceTable = Customer;
    DelayedInsert = true;
    ODataKeyFields = SystemId;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(id; Rec.SystemId)
                {
                    Caption = 'Id';
                    Editable = false;
                }
                field(number; Rec."No.")
                {
                    Caption = 'Number';
                }
                field(displayName; Rec.Name)
                {
                    Caption = 'Display Name';
                }
                field(email; Rec."E-Mail")
                {
                    Caption = 'Email';
                }
                field(balanceLCY; Rec."Balance (LCY)")
                {
                    Caption = 'Balance';
                    Editable = false;
                }
            }
            part(salesOrders; "MYAPP Sales Orders Subpage")
            {
                Caption = 'Sales Orders';
                EntityName = 'salesOrder';
                EntitySetName = 'salesOrders';
                SubPageLink = "Sell-to Customer No." = field("No.");
            }
        }
    }
}
```

### Verplichte properties

| Property | Regel |
|----------|-------|
| `PageType` | `API` |
| `APIPublisher` | camelCase, jouw bedrijfsnaam |
| `APIGroup` | camelCase, app-groep |
| `APIVersion` | `v1.0`, `v2.0`, of `beta` |
| `EntityName` | camelCase, enkelvoud |
| `EntitySetName` | camelCase, meervoud |
| `DelayedInsert` | `true` (verplicht voor API pages) |
| `ODataKeyFields` | `SystemId` (aanbevolen) |

### Veldnamen

- camelCase: `displayName`, `balanceLCY`, `currencyCode`
- Geen spaties, geen speciale tekens
- `id` voor SystemId, `number` voor "No."

---

## API Query

```al
query 50100 "MYAPP Top Customers"
{
    QueryType = API;
    APIPublisher = 'mycompany';
    APIGroup = 'myapp';
    APIVersion = 'v2.0';
    EntityName = 'topCustomer';
    EntitySetName = 'topCustomers';
    DataAccessIntent = ReadOnly;

    elements
    {
        dataitem(Customer; Customer)
        {
            column(number; "No.") { }
            column(displayName; Name) { }
            column(balanceLCY; "Balance (LCY)") { }
            column(city; City) { }

            dataitem(CustLedgerEntry; "Cust. Ledger Entry")
            {
                DataItemLink = "Customer No." = Customer."No.";
                SqlJoinType = LeftOuterJoin;

                column(documentType; "Document Type") { }
                column(amount; Amount) { }
            }
        }
    }
}
```

- `DataAccessIntent = ReadOnly` verplicht voor query APIs
- Gebruik `SqlJoinType` voor efficiënte joins

---

## Nested Parts / $expand

```
GET /api/mycompany/myapp/v2.0/customers?$expand=salesOrders
```

Subpage parts worden automatisch als `$expand` beschikbaar:

```al
part(salesOrders; "MYAPP Sales Orders Subpage")
{
    EntityName = 'salesOrder';
    EntitySetName = 'salesOrders';
    SubPageLink = "Sell-to Customer No." = field("No.");
}
```

De subpage is zelf ook een API page:

```al
page 50101 "MYAPP Sales Orders Subpage"
{
    PageType = API;
    EntityName = 'salesOrder';
    EntitySetName = 'salesOrders';
    SourceTable = "Sales Header";
    DelayedInsert = true;
    ODataKeyFields = SystemId;
    // Geen APIPublisher/APIGroup/APIVersion — wordt van parent geërfd
    ...
}
```

---

## Filtering & Ordering

```
GET /api/v2.0/customers?$filter=balanceLCY gt 1000&$orderby=displayName asc&$top=10&$skip=20
```

| Operator | Voorbeeld |
|----------|-----------|
| `eq` | `$filter=number eq '10000'` |
| `ne` | `$filter=blocked ne 'All'` |
| `gt`, `ge`, `lt`, `le` | `$filter=balanceLCY gt 1000` |
| `and`, `or` | `$filter=city eq 'Amsterdam' and balanceLCY gt 0` |
| `contains` | `$filter=contains(displayName, 'Smith')` |
| `startswith` | `$filter=startswith(number, '1')` |

---

## Pagination & ETags

BC API responses bevatten `@odata.nextLink` bij meer dan 100 records:

```json
{
    "value": [...],
    "@odata.nextLink": "https://host/api/v2.0/customers?$skip=100"
}
```

ETags voor optimistic concurrency:
```
GET → response bevat "@odata.etag": "W/\"abc123\""
PATCH met header: If-Match: W/"abc123"
```

---

## Bound Actions

```al
[ServiceEnabled]
procedure PostDocument(var ActionContext: WebServiceActionContext)
var
    SalesHeader: Record "Sales Header";
begin
    SalesHeader.Get(Rec."Document Type", Rec."No.");
    SalesHeader.SendToPosting(Codeunit::"Sales-Post");

    ActionContext.SetObjectType(ObjectType::Page);
    ActionContext.SetObjectId(Page::"MYAPP Sales Invoice API");
    ActionContext.AddEntityKey(SalesHeader.FieldNo(SystemId), SalesHeader.SystemId);
    ActionContext.SetResultCode(WebServiceActionResultCode::Created);
end;
```

Aanroep:
```
POST /api/mycompany/myapp/v2.0/salesOrders({id})/Microsoft.NAV.postDocument
```

---

## Authenticatie Patronen

### OAuth 2.0 (SaaS — aanbevolen)

```
POST https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token
Content-Type: application/x-www-form-urlencoded

client_id={app-id}&scope=https://api.businesscentral.dynamics.com/.default&client_secret={secret}&grant_type=client_credentials
```

### Basic Auth (On-Prem)

```bash
curl -sk -u "username:password" \
  "https://host:7049/instance/api/v2.0/companies"
```

### Web Service Access Key (SaaS — deprecated)

Gebruik OAuth. Web Service Access Keys worden uitgefaseerd.

---

## Veelgemaakte Fouten

| Fout | Oplossing |
|------|-----------|
| Missing `APIGroup` | Verplicht — zonder dit is de API niet bereikbaar |
| EntityName met spaties | Gebruik camelCase: `salesOrder` niet `"Sales Order"` |
| `Editable = true` op FlowFields | FlowFields zijn altijd read-only in APIs |
| Geen `DelayedInsert` | Verplicht — zonder dit falen POST requests |
| `ODataKeyFields` op "No." | Gebruik `SystemId` — "No." kan wijzigen bij nummerseries |
| API page extension | Niet mogelijk — maak een nieuwe API page |
| `DataAccessIntent` op schrijf-API | Alleen voor read-only queries |
