<!-- Uit appfabriek/claude-skills (gearchiveerd 2026-10-11). Gedeelde BC-kennis voor AL-projecten. -->

# Gedeelde BC Development Kennis

Deze instructies gelden voor alle BC AL-projecten.

## Build & Deploy (AL-projecten)

### Compileren

Zoek het AL-project (map met `app.json`), lees `launch.json` en `settings.json` voor configuratie.

```bash
# Zoek compiler (macOS)
ALC=$(find ~/.vscode/extensions -path "*/ms-dynamics-smb.al-*/bin/darwin/alc" 2>/dev/null | sort -V | tail -1)

# Compileer
cd "<map-met-app.json>"
"$ALC" /project:"." /packagecachepath:".alpackages" /out:"/tmp/bc-dev-publish.app" \
  /assemblyprobingpaths:"<komma-gescheiden bestaande paden uit settings.json>"
```

- Lees `al.assemblyProbingPaths` uit `.vscode/settings.json` — filter op paden die bestaan (`test -d`)
- `.alpackages/` moet gevuld zijn met platform symbols en dependency apps
- Nieuwste Agrio Connections app uit `../connections/` in `.alpackages/` zetten (huidige versie: 4.0.1.20)

### Publiceren via Dev Endpoint

Stel endpoint samen uit `launch.json` (`server`, `serverInstance`, `tenant`):

```bash
curl -sk -X POST \
  "https://<hostname>:7049/<instance>/dev/apps?tenant=<tenant>&SchemaUpdateMode=ForceSync" \
  -u "<username>:<password>" \
  -F "file=@/tmp/bc-dev-publish.app;type=application/octet-stream"
```

- Gebruik ALTIJD `-F` (multipart form), NOOIT `--data-binary` (geeft HTTP 415)
- Credentials: `admin` / `Qwelle1234()`
- ForceSync voor dev, Synchronize voor accept-omgevingen

## Remote Diagnostics

Remote AL-code uitvoeren op een BC-omgeving via GitHub Actions (`bc-diagnostic.yaml` workflow). Schrijf de body van een `Execute(var pCduResult: Codeunit "Diagnostic Result")` procedure en trigger via:

```bash
cat > /tmp/diag.al << 'ALEOF'
    var
        ...
    begin
        ...
    end;
ALEOF

gh workflow run bc-diagnostic.yaml -f environment="<omgeving>" -F al_code=@/tmp/diag.al
```

Result API: `pCduResult.Set('key', 'value')`, `.SetInteger()`, `.SetBoolean()`, `.SetObject()`, `.SetArray()`, `.AddRecord()`, `.Log()`, `.SetError()`.

## AL Code Style & Conventions

### Bestandsnamen

NAV suffix convention: `<ObjectName>.<ObjectType>.al` (bijv. `DocumentHeader.Table.al`, `SampleReport.Codeunit.al`, `TransportCard.Page.al`)

### Variable Naming

- `g` = global, `l` = local, `p` = parameter
- Global type hints: `gCdu` = codeunit, `gRec` = record, `gTxt`/`gText` = text, `gboo`/`gBln` = boolean, `gInt` = integer, `gDec` = decimal, `gDate` = date

### Procedure Naming

- `f` prefix = shared utility function, aangeroepen vanuit andere objecten — signatures stabiel houden
- `fl` prefix = flow procedure (kan state wijzigen)
- `fTry` prefix = `[TryFunction]` (returned boolean, geen error)

### Change-Tracking Annotations

```al
//>> [DATE] [INITIALS] – reason
// ... changed code ...
//<< [DATE] [INITIALS]
```

### AL-patronen

- Gebruik explicit `FIELD(...)`, `CONST(...)` en quoted identifiers in `DataItemTableView` en `TableRelation`
- Guard flags (`gbooSkipValidateForLoop`, `gBlnNoValidation`) voorkomen oneindige `VALIDATE`-recursie — altijd resetten na gebruik
- `Error('')` annuleert een actie stil — vervang dit nooit door een expliciet bericht tenzij je het gedrag bewust wilt wijzigen

## Vertalingen

Bij nieuwe/gewijzigde Caption, ToolTip of Label in AL-code: voeg vertalingen toe in alle taalbestanden (nl-NL, nl-BE, fr-FR, fr-BE, de-DE). Gebruik `state="needs-translation"` als de vertaling onbekend is.

## Commit Conventions

```
<type>(<scope>): <beschrijving> (#<issue-nr>)

Types: feat, fix, refactor, chore, docs
```

Schrijf een functionele omschrijving (wat merkt de gebruiker), niet technisch (welke bestanden zijn gewijzigd).

## PR Workflow

Bij "maak PR" altijd:
1. Nieuwe branch aanmaken vanuit de huidige branch
2. Wijzigingen committen
3. Pushen met `-u` flag
4. PR aanmaken via `gh pr create`
5. **PR URL teruggeven en STOPPEN** — niet zelf mergen, tenzij de gebruiker daar expliciet om vraagt

## GitHub Issues

Alle codewijzigingen vereisen een GitHub Issue. Maak eerst een issue aan voordat je code aanpast — ook voor kleine bugfixes of refactors. Refereer het issuenummer in elke commit message.

## Compileren — Verplicht voor Oplevering

De app MOET altijd compileren zonder errors voordat een aanpassing wordt opgeleverd. Geef nooit een code-aanpassing terug zonder te bevestigen dat het project compileert.
