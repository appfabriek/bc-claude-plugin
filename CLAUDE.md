# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Claude Code plugin for Business Central AL development. Provides 19 skills and a comprehensive BC knowledge base so Claude is immediately productive in any AL project — no context-building needed.

## Development Workflow (Superpowers-inspired)

Follow this workflow for ALL BC development work. Adapted from [obra/superpowers](https://github.com/obra/superpowers).

### 1. Design before code
- Never jump into coding. First understand the problem.
- Read project context: `app.json`, `CLAUDE.md`, recent commits.
- Propose 2-3 approaches with trade-offs when the solution isn't obvious.
- Get approval before writing code.

### 2. Plan with exact details
- Break work into small tasks (exact file paths, object IDs, procedure names).
- No vague steps like "add appropriate validation" — be specific.
- Each task independently verifiable.

### 3. Compile-verify cycle (AL equivalent of TDD)
- The "red-green" cycle: describe expected behavior → make change → compile → publish → verify.
- Never claim "done" without a successful compile.
- Use `/dev-publish` after every change to verify.
- Use `/diagnose` or `/bc-query` to verify behavior on the server.

### 4. Systematic debugging
- Read BC error messages completely.
- Reproduce consistently before attempting fixes.
- One hypothesis, one change, verify. No shotgun fixes.
- After 3 failed attempts: question the approach, escalate to the developer.

### 5. Evidence over claims
- Always compile the app before delivering changes.
- Show compile output or publish result as evidence.
- "It should compile" is never acceptable.
- Run `/bc-review` to verify code quality.

### 6. Small, focused changes
- One logical change per commit.
- Functional commit messages (what the user will notice).
- One issue per PR.

---

## Project Context Intake

At the start of every new conversation, if project context is not yet clear, ask the developer these questions — one at a time, stop as soon as the answer is "not relevant":

1. **"BC versie en deployment model?"** (bv. BC26 SaaS, BC23 on-prem, BC14 on-prem legacy)
2. **"ISV/AppSource app, partner maatwerk, of intern project?"** (bepaalt: AppSourceCop, prefix-regel, entitlements, breaking change beleid)
3. **"Welke andere apps hangen ervan af, of waarvan ben jij afhankelijk?"** (dependency chain — kritiek voor upgrade- en obsolete-beslissingen)
4. **"Is er een testomgeving / container beschikbaar, en hoe publiceer je nu?"** (bepaalt welke `/bc-ps` en `/dev-publish` aanpak werkt)
5. **"Wat is het huidige pijnpunt of de taak van vandaag?"** (focus — sla de rest over als dit al genoeg context geeft)

Once answered, summarize in 3 bullets and confirm before proceeding. Store as session context — no need to ask again within the same session.

If the developer opens with a concrete task, skip straight to it and ask only the questions directly relevant.

---

## Auto-Detect Project Context

When working in an AL project, automatically read and apply:
- `app.json` → prefix, ID ranges, publisher, runtime version, dependencies
- `.vscode/launch.json` → server, tenant, environment configurations
- `.vscode/settings.json` → assembly probing paths, analyzers
- `.alpackages/` → available dependencies and symbols
- `AppSourceCop.json` → mandatory affixes, baseline app

Set these as "current project facts" so every command automatically uses them.

---

## Skills (19 commands)

### Build & Deploy
| Skill | Purpose |
|-------|---------|
| `/dev-publish` | Compile & publish AL app to BC dev server |
| `/bc-ps` | Generate BcContainerHelper PowerShell scripts |
| `/bc-devops` | Generate/update GitHub Actions CI/CD workflows |

### Diagnostics & Data
| Skill | Purpose |
|-------|---------|
| `/diagnose` | Run remote AL diagnostics via GitHub Actions |
| `/bc-query` | Data questions in plain language |
| `/bc-env` | Inspect BC environment: apps, versions, compare |

### Code Quality
| Skill | Purpose |
|-------|---------|
| `/bc-review` | Review AL code against Microsoft guidelines |
| `/bc-perf` | Scan for performance anti-patterns |
| `/bc-test` | Generate and run AL test codeunits |

### Code Generation
| Skill | Purpose |
|-------|---------|
| `/bc-new` | Scaffold new AL objects (table, page, codeunit, etc.) |
| `/bc-api` | Generate API page or API query |
| `/bc-copilot` | Scaffold BC Copilot capability (System.AI) |
| `/bc-events` | List, subscribe to, or publish BC events |
| `/bc-permissions` | Generate or audit permission sets |
| `/bc-telemetry` | Add telemetry, review coverage, generate KQL |

### Lifecycle
| Skill | Purpose |
|-------|---------|
| `/bc-upgrade` | Analyze and generate upgrade codeunits |
| `/bc-migrate` | BC version migration assistant |
| `/bc-translate` | Sync translations across all XLF files |
| `/bc-product` | ISV product workflow: spec, roadmap, changelog |

## Knowledge Base (19 files)

Skills read these automatically. No extra setup needed.

| File | Content |
|------|---------|
| `al-guidelines.md` | Microsoft AL naming, patterns, performance, events, upgrades |
| `bc-tables.md` | Standard BC tables with field numbers |
| `diagnostic-recipes.md` | Proven AL diagnostic snippets |
| `bc-events.md` | Publisher events catalog per domain |
| `bc-api-patterns.md` | API page/query patterns and authentication |
| `bc-test-patterns.md` | Test codeunit structure and library reference |
| `bc-copilot-patterns.md` | System.AI, PromptDialog, capability registration |
| `bc-telemetry-patterns.md` | Session.LogMessage, custom dimensions, KQL |
| `bc-upgrade-patterns.md` | UpgradeTag, DataTransfer, obsolete lifecycle |
| `bc-permissions.md` | Permission sets, entitlements, audit |
| `bc-dataverse.md` | CDS integration tables, coupling, sync |
| `bc-devops-patterns.md` | GitHub Actions, app signing, deployment |
| `bc-powershell.md` | BcContainerHelper cmdlet reference |
| `bc-appsource.md` | AppSource submission, compliance, checklist |
| `bc-architecture-decisions.md` | Senior-level architecture guidance |
| `bc-version-matrix.md` | Feature availability per BC version |
| `bc-debugging.md` | Debugging modes, snapshot, profiler, SQL debug |
| `bc-static-analysis.md` | CodeCop, AppSourceCop, ALCops, rulesets |
| `bc-reports.md` | Report layouts, rendering syntax, extensions |

## Plugin Structure

```
.claude-plugin/plugin.json   # Plugin metadata
commands/                    # Skill definitions (Markdown with YAML frontmatter)
knowledge/                   # BC knowledge base (Markdown)
netframework-ref/v4.7.2/     # .NET Framework 4.7.2 DLLs for AL compiler (gitignored)
```

## Developing Skills

Edit `.md` files in `commands/` for skill behavior, `knowledge/` for shared context. Changes take effect after reinstalling the plugin locally. All skill files have YAML frontmatter with `name`, `description`, and `bc-version`.

## MCP Server Integration (Optional)

For direct BC API access as alternative to GitHub Actions, connect a BC MCP server (Basic Auth) to your Claude Code configuration. This enables `/bc-query` and `/bc-env` to work without the GitHub Actions round-trip.
