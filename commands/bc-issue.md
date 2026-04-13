---
name: bc-issue
description: Pak een GitHub issue op en implementeer het volledig — branch, code, build, vertaling, PR
bc-version: ">=14.0"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# BC Issue

Volledige workflow voor het oppakken en afronden van een GitHub issue in een BC AL-project.

## Input

$ARGUMENTS — optioneel issuenummer, bijvoorbeeld:
- (leeg) — laat de skill het beste beschikbare issue kiezen
- "56" — pak issue #56 op
- "check" — toon alleen welke issues beschikbaar zijn, doe niets

## Instructies

### Stap 0 — Lees projectcontext

1. Lees `al-guidelines.md` uit de knowledge/ map van de bc-claude-plugin.
   Zoek het bestand met: `find ~/.claude/plugins/bc-claude-plugin/knowledge ./.claude/plugins/bc-claude-plugin/knowledge ~/.local/share/claude/plugins/bc-claude-plugin/knowledge ~/code/bc-claude-plugin/knowledge -name "al-guidelines.md" 2>/dev/null | head -1`
2. Lees `app.json` → `name`, `version`.
3. Lees `CLAUDE.md` in de projectroot voor projectspecifieke conventies (commit-stijl, branch-naamgeving, build-commando).

### Stap 1 — Selecteer issue

**Als issuenummer opgegeven:**
```bash
gh issue view <nr> --json number,title,body,labels,assignees,state
```

**Als leeg (automatische selectie):**
```bash
gh issue list --state open --limit 30 --json number,title,labels,assignees
```

Kies het beste beschikbare issue op basis van:
- **Voorrang:** niet toegewezen, geen "blocked" / "wontfix" / "by design" label
- **Geschiktheid:** duidelijke beschrijving, geen externe afhankelijkheden die nog niet klaar zijn
- **Omvang:** verberg issues die duidelijk meerdere sprints beslaan

Lees bij twijfel ook `docs/ISSUES.md` of `ISSUES.md` voor prioritering.

**Als "check":** Toon de lijst en stop.

**Geblokkeerde issues herkennen:**
- Label: `blocked`, `wontfix`, `by design`, `duplicate`, `needs-design`
- Body bevat: "wacht op", "depends on #", "needs BC" + versienummer hoger dan huidig
- Milestone ver in de toekomst

Sla geblokkeerde issues over en leg uit waarom. Kies dan het volgende beschikbare.

### Stap 2 — Beoordeel het issue

Lees de volledige issue-body en bepaal:

1. **Type wijziging:**
   - `ui` — alleen page-aanpassingen, Captions, Labels, Tooltips
   - `logic` — wijzigingen in Codeunit, trigger, berekening
   - `fix` — bugfix (kan beide zijn)
   - `config` — app.json, launch.json, workflow-bestanden
   - `ci` — GitHub Actions, scripts

2. **Scope:** Welke AL-bestanden zijn waarschijnlijk betrokken?

3. **Heeft dit Labels/Captions nodig?** (→ stap 6 verplicht)

4. **Zijn er AL-tests schrijfbaar?** (zie stap 5)

Meld je bevindingen kort aan de gebruiker vóór je begint.

### Stap 3 — Maak branch aan

Controleer eerst of je niet al op de juiste branch zit:
```bash
git branch --show-current
```

Branch-naamconventie (lees uit CLAUDE.md, anders gebruik dit):
```
feature/<issue-nr>-<korte-slug-van-titel>
```

Voorbeelden: `feature/56-hardcoded-berichten-labels`, `feature/89-ci-netpackages-fix`

```bash
git checkout main
git pull
git checkout -b feature/<nr>-<slug>
```

**Controleer op conflicten** met openstaande branches:
```bash
git branch -r | grep "feature/"
```

### Stap 4 — Implementeer

Lees altijd de relevante bestanden vóórdat je schrijft. Begrijp het bestaande patroon.

#### Bij type `logic` of `fix` met testbare logica:

Gebruik `bc-test` om een AL-test te schrijven **vóórdat** je de implementatie doet:
```
/bc-test <naam-van-codeunit>
```

Volg RED-GREEN-REFACTOR:
1. Schrijf de test — zorg dat die faalt om de juiste reden
2. Schrijf minimale implementatie
3. Verifieer dat de test slaagt
4. Refactor indien nodig

#### Bij type `ui`, of als er geen testinfrastructuur is:

Ga direct naar implementatie. Lees de betrokken `.al`-bestanden eerst volledig.

**Regels:**
- Schrijf Engelse base-tekst voor nieuwe Labels, Captions, ToolTips
- Volg de variabelenaming uit CLAUDE.md (`g`/`l`/`p` prefix, etc.)
- Voeg change-tracking annotaties toe: `//>> [DATUM] [INITIALEN] – reden ... //<< [DATUM]`
- Geen speculative features: implementeer alleen wat het issue vraagt

### Stap 5 — Bouw de app

Bouw verplicht na de implementatie. Zoek het build-commando in CLAUDE.md of gebruik:

```bash
# Zoek alc.exe
find ~/.vscode/extensions -name "alc.exe" 2>/dev/null | sort -r | head -1
```

```powershell
# Of via het projectscript als dat bestaat
pwsh -NoLogo -NoProfile -File "scripts/Build-App.ps1"
```

**De build MOET slagen zonder errors.** Waarschuwingen zijn toegestaan.

Als de build faalt:
- Lees de foutmeldingen zorgvuldig
- Los compiler-errors op vóórdat je doorgaat
- Bouw opnieuw tot clean

### Stap 6 — Vertalingen bijwerken

**Verplicht als** de implementatie nieuwe of gewijzigde Captions, Labels of ToolTips bevat.

```
/bc-translate
```

De skill detecteert automatisch welke trans-units ontbreken en voegt ze toe, inclusief bekende NL-vertalingen uit de git diff.

Sla deze stap niet over — ontbrekende vertalingen veroorzaken `needs-translation`-vervuiling in de XLF-bestanden.

### Stap 7 — Maak PR aan

```bash
git add <gewijzigde bestanden>
git commit -m "<type>(<scope>): <beschrijving> (#<nr>)"
git push -u origin feature/<nr>-<slug>
gh pr create --title "<type>(<scope>): <beschrijving> (#<nr>)" --body "..."
```

PR-body bevat minimaal:
- Samenvatting van de wijziging (2-3 bullets)
- Verwijzing naar het issue (`Closes #<nr>`)
- Testplan (wat handmatig te verifiëren is)

### Stap 8 — Rapporteer

Toon aan de gebruiker:
- Issue opgepakt: #nr — titel
- Branch: `feature/...`
- Gewijzigde bestanden (kort)
- Build: ✓ geslaagd
- Vertalingen: bijgewerkt / niet van toepassing
- PR: link

## Regels

- Lees bestanden altijd vóór je ze bewerkt
- Bouw altijd na de implementatie — lever nooit niet-compilerende code op
- Roep altijd `/bc-translate` aan als er Label/Caption-wijzigingen zijn
- Maak altijd een feature-branch — commit nooit direct op main
- Refereer het issuenummer in elke commit message
- Controleer op geblokkeerde issues vóór implementatie — leg uit waarom je een issue oversloeg
- Voeg geen features toe die het issue niet vraagt
