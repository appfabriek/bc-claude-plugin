# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in Business Central AL projects. It is loaded automatically when this plugin is installed.

## Proactive Knowledge Loading

When you detect you are working in an AL project (any directory with `app.json`), **automatically read the relevant knowledge files from this plugin BEFORE writing or reviewing code**. Do not wait for a slash command — apply this knowledge in every response.

### Always read (in any AL context):

- `al-guidelines.md` — naming conventions, code structure, record operations, error handling, events, performance. **This is your AL style guide. Follow it strictly.**
- `bc-tables.md` — standard BC table numbers, field numbers, option values. **Use this instead of guessing field numbers.**

### Read on-demand based on what the developer is working on:

| Developer is working on... | Read this knowledge file |
|---------------------------|--------------------------|
| API pages, OData, REST endpoints | `bc-api-patterns.md` |
| Events, subscribers | `bc-events.md` |
| Tests | `bc-test-patterns.md` |
| Upgrade codeunits, obsolete fields | `bc-upgrade-patterns.md` |
| Permission sets, entitlements | `bc-permissions.md` |
| Telemetry, Application Insights, KQL | `bc-telemetry-patterns.md` |
| Copilot, AI capabilities, System.AI | `bc-copilot-patterns.md` |
| Dataverse, CDS integration | `bc-dataverse.md` |
| Reports, layouts, RDLC, Word | `bc-reports.md` |
| CI/CD, GitHub Actions, pipelines | `bc-devops-patterns.md` |
| BcContainerHelper, PowerShell, containers | `bc-powershell.md` |
| AppSource submission, compliance | `bc-appsource.md` |
| Architecture decisions, table design | `bc-architecture-decisions.md` |
| Performance problems, profiling | `bc-debugging.md` |
| Code analyzers, linters, rulesets | `bc-static-analysis.md` |
| BC version differences, migration | `bc-version-matrix.md` |
| Remote diagnostics, data queries | `diagnostic-recipes.md` |

### How to find knowledge files

Knowledge files are in the `knowledge/` directory of this plugin. Locate them with:

```bash
find ~/.claude/plugins/bc-claude-plugin/knowledge \
     ./.claude/plugins/bc-claude-plugin/knowledge \
     ~/.local/share/claude/plugins/bc-claude-plugin/knowledge \
     ~/code/bc-claude-plugin/knowledge \
     -name "<filename>" 2>/dev/null | head -1
```

---

## Project Context Intake

At the start of every new conversation in an AL project, if context is not yet clear, ask these questions — one at a time, stop when you have enough:

1. **"BC versie en deployment model?"** (BC26 SaaS, BC23 on-prem, etc.)
2. **"ISV/AppSource app, partner maatwerk, of intern project?"**
3. **"Welke dependency apps heb je?"**
4. **"Hoe publiceer je nu?"** (container, dev endpoint, etc.)
5. **"Wat is de taak van vandaag?"**

If the developer opens with a concrete task, skip straight to it.

---

## Auto-Detect Project Context

When working in an AL project, automatically read:
- `app.json` → prefix, ID ranges, publisher, runtime version, dependencies
- `.vscode/launch.json` → server, tenant, environment configurations
- `.vscode/settings.json` → assembly probing paths, analyzers
- `AppSourceCop.json` → mandatory affixes, baseline app (if present)

---

## Development Workflow

Follow this workflow for ALL BC development work:

1. **Start with an issue** — use `/bc-issue` to pick up and implement a GitHub issue end-to-end
2. **Design before code** — understand the problem, propose approaches
3. **Plan with exact details** — file paths, object IDs, procedure names
4. **Compile-verify cycle** — compile after every change, verify on server
5. **Systematic debugging** — read errors completely, one fix at a time
6. **Evidence over claims** — show compile output, never say "should work"
7. **Small, focused changes** — one change per commit
8. **Translations last** — run `/bc-translate` after every change that adds Labels, Captions, or ToolTips

---

## Available Commands (20)

| Command | Purpose |
|---------|---------|
| `/bc-issue` | Pick up a GitHub issue end-to-end: branch → code → build → translate → PR |
| `/dev-publish` | Compile & publish AL app to BC dev server |
| `/diagnose` | Run remote AL diagnostics via GitHub Actions |
| `/bc-query` | Data questions in plain language |
| `/bc-env` | Inspect BC environment: apps, versions |
| `/bc-review` | Review AL code against Microsoft guidelines |
| `/bc-perf` | Scan for performance anti-patterns |
| `/bc-test` | Generate and run AL test codeunits |
| `/bc-new` | Scaffold new AL objects |
| `/bc-api` | Generate API page or query |
| `/bc-copilot` | Scaffold BC Copilot capability |
| `/bc-events` | List, subscribe to, or publish events |
| `/bc-permissions` | Generate or audit permission sets |
| `/bc-telemetry` | Add telemetry, generate KQL |
| `/bc-upgrade` | Analyze and generate upgrade codeunits |
| `/bc-migrate` | BC version migration assistant |
| `/bc-translate` | Sync XLF translations; auto-detects NL vertalingen uit git diff |
| `/bc-product` | ISV spec, roadmap, changelog |
| `/bc-ps` | Generate BcContainerHelper scripts |
| `/bc-devops` | Generate GitHub Actions CI/CD workflows |
