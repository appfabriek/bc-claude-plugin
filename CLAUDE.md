# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Claude Code plugin (`bc-claude-plugin`) providing skills and a knowledge base for Business Central AL development. The plugin gives Claude built-in BC expertise so it can work effectively in any AL project without needing to research conventions, table structures, or patterns each time.

## Skills

| Skill | File | Purpose |
|-------|------|---------|
| `/dev-publish` | [commands/dev-publish.md](commands/dev-publish.md) | Compile & publish AL app to BC dev server |
| `/diagnose` | [commands/diagnose.md](commands/diagnose.md) | Run remote AL diagnostics via GitHub Actions |
| `/bc-translate` | [commands/bc-translate.md](commands/bc-translate.md) | Sync translations across all XLF language files |
| `/bc-review` | [commands/bc-review.md](commands/bc-review.md) | Review AL code against Microsoft guidelines |
| `/bc-query` | [commands/bc-query.md](commands/bc-query.md) | Ask data questions in plain language |
| `/bc-env` | [commands/bc-env.md](commands/bc-env.md) | Inspect BC environment: installed apps, versions |

## Knowledge base

| File | Content |
|------|---------|
| [knowledge/al-guidelines.md](knowledge/al-guidelines.md) | Microsoft AL naming, patterns, performance, events, upgrades |
| [knowledge/bc-tables.md](knowledge/bc-tables.md) | Standard BC tables with field numbers and option values |
| [knowledge/diagnostic-recipes.md](knowledge/diagnostic-recipes.md) | Proven AL snippets for common diagnostic queries |

Skills read these knowledge files automatically — no setup needed.

## Plugin structure

```
.claude-plugin/plugin.json   # Plugin metadata
commands/                    # Skill definitions (Markdown)
knowledge/                   # BC knowledge base (Markdown)
netframework-ref/v4.7.2/     # .NET Framework 4.7.2 DLLs for AL compiler (gitignored)
```

## Developing skills

Skills are instruction-based Markdown files. Edit the relevant `.md` file in `commands/` to change skill behavior. Knowledge files in `knowledge/` are referenced by skills and provide shared context. No compilation or tooling required — changes take effect after reinstalling the plugin locally.

## .NET Framework reference assemblies (macOS)

The AL compiler requires .NET Framework 4.7.2 DLLs (not included in the AL VS Code extension). These live in `netframework-ref/v4.7.2/` (gitignored). See README.md for setup instructions.

## Key rules encoded in the skills

**dev-publish:**
- Always use `-F` (multipart form) for curl upload, never `--data-binary` (causes HTTP 415)
- Use `-sk` to skip SSL validation on dev servers (self-signed certs)
- Filter `al.assemblyProbingPaths` to existing directories; skip Windows paths
- `.alpackages/` must be populated before compiling

**diagnose / bc-query:**
- Self-hosted runners execute sequentially — never trigger multiple workflow runs in parallel
- Use `RecordRef` + `FieldRef` for virtual/system tables; `RecordRef.SetFilter()` does not exist
- Limit results with a counter (max ~100 records)

**bc-review:**
- Uses Microsoft official naming conventions (PascalCase, no Hungarian notation)
- Distinguishes new code (strict) from existing/legacy code (tolerant)

**bc-translate:**
- Never overwrite existing translations
- Always use `state="needs-translation"` for new entries
