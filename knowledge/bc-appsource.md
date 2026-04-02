# BC AppSource Submission & Compliance

Kennis voor het publiceren van BC extensions op Microsoft AppSource.

---

## AppSourceCop Regels (meest schendende)

### Breaking Changes (blokkeren submission)

| Regel | Beschrijving | Oplossing |
|-------|-------------|-----------|
| AS0001 | Tabel verwijderd | Eerst `ObsoleteState = Pending`, pas na major bump `Removed` |
| AS0002 | Veld verwijderd | Idem: Pending → Removed lifecycle |
| AS0004 | Veld-type of length gewijzigd | Maak nieuw veld, migreer data, markeer oud als Pending |
| AS0005 | Veld hernoemd | Nooit hernoemen na publicatie — maak nieuw veld |
| AS0011 | Object niet geprefixed | Alle objecten moeten `affixes` bevatten uit `AppSourceCop.json` |
| AS0023 | Return type van publieke procedure gewijzigd | Versie-breaking — maak nieuwe procedure |
| AS0049 | `Removed` zonder `Pending` eerst | Altijd eerst één release met `Pending` |
| AS0080 | Veldlengte verkleind | Mag niet — alleen vergroten of gelijk houden |
| AS0084 | Dubbel App ID | Elk app ID moet uniek zijn in AppSource |
| AS0088 | Object verwijderd zonder Pending | Altijd obsolete lifecycle volgen |

### AppSourceCop.json

```json
{
    "mandatoryAffixes": ["MYAPP"],
    "supportedCountries": ["nl", "be", "de", "fr"],
    "publisher": "My Company",
    "baselineAppPath": "./baseline/MyApp_1.0.0.0.app"
}
```

- `mandatoryAffixes`: alle objecten moeten dit prefix/suffix bevatten
- `baselineAppPath`: vorige gepubliceerde versie — compiler vergelijkt hiertegen

### Activeren in app.json

```json
{
    "preprocessorSymbols": [],
    "suppressWarnings": [],
    "mandatoryAffixes": ["MYAPP"]
}
```

---

## Submission Workflow

### Partner Center Flow

1. **Ontwikkel & test** — lokaal + automated tests
2. **AppSourceCop clean** — geen errors, geen warnings
3. **Technical validation** — upload naar Partner Center, Microsoft voert automated checks uit
4. **Content review** — Microsoft review van listing, screenshots, help URLs
5. **Certification** — Microsoft test op clean tenant
6. **Go-live** — beschikbaar in AppSource marketplace

### Technische Validatiestappen (Microsoft)

1. App compileert tegen alle ondersteunde BC versies
2. AppSourceCop regels: geen errors
3. Geen hardcoded URLs of tenant-specifieke data
4. Alle tabelvelden hebben `DataClassification` (niet `ToBeClassified`)
5. Alle captions vertegenwoordigd in XLF-bestanden
6. Performance tests: geen extreem lange operaties
7. Geen deprecated API-aanroepen
8. Entitlements correct voor de gekozen licentieplannen

### Veelgemaakte Afwijzingsredenen

| Reden | Oplossing |
|-------|-----------|
| Missing DataClassification | Zet op elk tabel-veld, niet `ToBeClassified` |
| Missing translations | Alle Caption/ToolTip in XLF voor ondersteunde talen |
| Hardcoded URLs | Gebruik Setup-tabel of Isolated Storage |
| Breaking change vs baseline | Fix AppSourceCop errors, gebruik obsolete lifecycle |
| Missing entitlements | Voeg Entitlement objects toe voor alle plans |
| Logo/listing issues | Correct formaat (216x216 PNG), goede beschrijving |
| Missing privacy/EULA URLs | Vul in app.json: `privacyStatement`, `EULA`, `help`, `url` |

---

## Hotfix vs Major Release

### Hotfix (patch)

- Alleen bugfixes, geen nieuwe features
- Zelfde major.minor versie: `1.2.3.0` → `1.2.4.0`
- Geen breaking changes toegestaan
- Snellere review in Partner Center

### Major Release

- Nieuwe features, breaking changes (met obsolete lifecycle)
- Major of minor versie bump: `1.2.0.0` → `2.0.0.0` of `1.3.0.0`
- Volledige review
- `ObsoleteState = Removed` alleen bij major bump

### Beslisboom

```
Bug gevonden in productie?
├── Ja → Hotfix (patch versie bump, geen schema changes)
└── Nee → Nieuwe feature?
    ├── Ja + breaking change → Major release (obsolete lifecycle)
    └── Ja, geen breaking → Minor release
```

---

## Entitlements & Licensing

### Entitlement Object

```al
entitlement "MYAPP Premium Users"
{
    Type = PerUserServicePlan;
    Id = '8e9002c0-a1d8-4465-b952-817d2948e6e2'; // BC Premium

    ObjectEntitlements =
        "MYAPP - Admin",
        "MYAPP - Basic";
}

entitlement "MYAPP Essential Users"
{
    Type = PerUserServicePlan;
    Id = '920656a2-7dd8-4c83-97b6-a356414dbd36'; // BC Essential

    ObjectEntitlements =
        "MYAPP - Basic";
}

entitlement "MYAPP Team Members"
{
    Type = PerUserServicePlan;
    Id = 'd9a6391b-8970-4976-bd94-5f205007c8d8'; // BC Team Member

    ObjectEntitlements =
        "MYAPP - ReadOnly";
}
```

### Trial Support

Nieuwe tenants krijgen automatisch een trial-periode. Zorg dat:
- Basis-functionaliteit werkt op Essential plan
- Premium features duidelijk gemarkeerd zijn
- Trial-gebruikers alle features zien (zodat ze upgraden)

---

## AppSource Requirements Checklist

### Verplicht

- [ ] `DataClassification` op elk tabelveld (niet `ToBeClassified`)
- [ ] Alle captions in XLF voor ondersteunde talen
- [ ] `mandatoryAffixes` in `AppSourceCop.json`
- [ ] Geen hardcoded URLs of tenant-specifieke data
- [ ] `privacyStatement`, `EULA`, `help`, `url` in app.json
- [ ] Logo: 216x216 PNG
- [ ] Entitlement objects voor relevante plans
- [ ] Geen `DotNet` interop (niet beschikbaar in SaaS)
- [ ] AppSourceCop: 0 errors
- [ ] Minimum BC versie: N-2 (huidige en twee vorige releases)

### Aanbevolen

- [ ] Automated tests (≥80% coverage voor kritieke paden)
- [ ] Telemetry via `Session.LogMessage`
- [ ] Copilot capabilities (als relevant)
- [ ] Performance tests voor zware operaties
- [ ] CodeCop + UICop + PerTenantExtensionCop clean
- [ ] Setup wizard voor eerste gebruik
- [ ] In-app help / tooltips op alle velden
