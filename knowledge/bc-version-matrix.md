# BC Version Matrix

Feature-beschikbaarheid per BC-versie. Skills gebruiken dit om te waarschuwen als een feature een minimum versie vereist.

---

## Versie ↔ Runtime Mapping

| BC Versie | Release | Runtime | Platform |
|-----------|---------|---------|----------|
| BC 21 | 2022 Wave 2 | 10.0 | 21.x |
| BC 22 | 2023 Wave 1 | 11.0 | 22.x |
| BC 23 | 2023 Wave 2 | 12.0 | 23.x |
| BC 24 | 2024 Wave 1 | 13.0 | 24.x |
| BC 25 | 2024 Wave 2 | 14.0 | 25.x |
| BC 26 | 2025 Wave 1 | 15.0 | 26.x |
| BC 27 | 2025 Wave 2 | 16.0 | 27.x |

---

## Feature Beschikbaarheid

### AL Taal Features

| Feature | Sinds | Runtime |
|---------|-------|---------|
| Interface types | BC 18 | 7.0 |
| PermissionSet objects (AL) | BC 18 | 7.0 |
| Entitlement objects | BC 20 | 9.0 |
| `ReadIsolation` property | BC 22 | 11.0 |
| `FindSet(true)` deprecated | BC 22 | 11.0 |
| `DataTransfer` | BC 20 | 9.0 |
| Collectible Errors | BC 19 | 8.0 |
| `ErrorInfo.Create()` | BC 19 | 8.0 |
| `NumberSequence` data type | BC 18 | 7.0 |
| Page Background Tasks | BC 15 | 4.0 |
| `Dictionary` / `List` types | BC 17 | 6.0 |
| `TextBuilder` | BC 17 | 6.0 |

### API & Integration

| Feature | Sinds | Runtime |
|---------|-------|---------|
| API v2.0 pages | BC 20 | 9.0 |
| API query type | BC 22 | 11.0 |
| Bound actions (`[ServiceEnabled]`) | BC 20 | 9.0 |
| OAuth 2.0 S2S (SaaS) | BC 20 | 9.0 |
| Webhooks v2.0 | BC 21 | 10.0 |
| `HttpClient` improvements | BC 22 | 11.0 |

### Copilot / AI

| Feature | Sinds | Runtime |
|---------|-------|---------|
| System.AI namespace | BC 23 | 12.0 |
| `AzureOpenAI` codeunit | BC 23 | 12.0 |
| `CopilotCapability` registratie | BC 24 | 13.0 |
| PromptDialog page type | BC 24 | 13.0 |
| Copilot Toolkit (GA) | BC 25 | 14.0 |

### Telemetry

| Feature | Sinds | Runtime |
|---------|-------|---------|
| `Session.LogMessage` | BC 16 | 5.0 |
| Custom dimensions (8 max) | BC 18 | 7.0 |
| App Insights connection string | BC 24 | 13.0 |
| Per-app telemetry via app.json | BC 22 | 11.0 |

### Security & Permissions

| Feature | Sinds | Runtime |
|---------|-------|---------|
| PermissionSet AL object | BC 18 | 7.0 |
| Entitlement objects | BC 20 | 9.0 |
| Security filter performance | BC 22 | 11.0 |
| Namespace support | BC 22 | 11.0 |

### Performance

| Feature | Sinds | Runtime |
|---------|-------|---------|
| `SetLoadFields` | BC 17 | 6.0 |
| Tri-state locking | BC 22 | 11.0 |
| NCCI (ColumnStoreIndex) | BC 22 | 11.0 |
| Partial records on API pages | BC 22 | 11.0 |
| Calculate only visible FlowFields | BC 26 | 15.0 |
| AL Profiler Sampling met SQL tracking | BC 27 | 16.0 |
| In-client debugging vanuit webclient | BC 27 | 16.0 |

### Deprecated / Removed

| Feature | Deprecated | Removed |
|---------|-----------|---------|
| `FindSet(true/true)` | BC 22 | — |
| SOAP web services | BC 21 | BC 27 |
| Web Service Access Keys | BC 24 | BC 26 |
| `Report.SaveAsExcel` (client) | BC 21 | — |
| Control Add-ins (partial) | BC 22 | — |
| `DotNet` interop (SaaS) | BC 14 | Niet beschikbaar in SaaS |

---

## Minimum Versie per Skill

| Skill | Minimum BC | Reden |
|-------|-----------|-------|
| `/bc-copilot` | BC 24 | CopilotCapability + PromptDialog |
| `/bc-telemetry --kql` | BC 18 | Custom dimensions in LogMessage |
| `/bc-api --query` | BC 22 | API query type |
| `/bc-upgrade --generate` | BC 20 | DataTransfer |
| `/bc-perf --scan` | BC 17 | SetLoadFields check relevant |
| `/bc-permissions --generate` | BC 18 | PermissionSet AL object |
| `/bc-test` | BC 15 | Stabiel test framework |
| `/bc-events` | BC 14 | Events altijd beschikbaar |

---

## app.json Runtime Versie

```json
{
    "runtime": "12.0",
    "platform": "23.0.0.0",
    "application": "23.0.0.0"
}
```

- `runtime`: bepaalt welke AL taalfeatures beschikbaar zijn
- `platform`: minimum BC platform versie
- `application`: minimum BC base application versie

**Vuistregel:** stel runtime in op de laagste versie die je wilt ondersteunen. Gebruik `runtime: "12.0"` (BC 23) als veilige moderne baseline.

---

## BC 27 en BC 28

### BC 27 (2025 Wave 2) — uitgebracht
- Sampling profiler (lichtgewicht performance analyse, met SQL tracking)
- Word layout add-in vernieuwd (BC27+)
- In-client debugging vanuit webclient
- SOAP web services definitief verwijderd

### BC 28 (2026 Wave 1) — preview
- Semantic search op data en metadata voor AL developers
- Fully qualified names / namespace support uitgebreid
- Custom agents (uitbreiding BC Copilot model)
- Database index usage management per company
- Default language per company voor documenten

### Tooling Transitie
- **LinterCop → ALCops:** LinterCop wordt read-only. Migreer naar ALCops in AL-Go-Settings.json zodra project op BC26+.
