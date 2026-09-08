# C/SIDE finsql import en compile (KMT)

Gebruik dit wanneer je Business Central C/SIDE-tekstobjecten (`OBJECT Codeunit …` in een `.txt`) importeert of compileert met `finsql.exe` (RTC Development Environment, BC14).

**Gebruik altijd het gebundelde script `scripts/kmt-finsql-import.ps1`.** Verzin geen eigen `finsql.exe`-aanroep. Elke valkuil hieronder heeft in de praktijk een import laten falen of laten hangen.

---

## Wanneer dit bestand lezen

- Import van C/SIDE `.txt` objecten naar een BC14-database
- Compile van een C/SIDE-object via finsql / RTC
- Iemand stelt een handmatige `Start-Process finsql.exe …` of `finsql command=importobjects,…` voor

Dit is **niet** voor AL-apps (`alc`, `/dev-publish`, NavAdminTool). Die gaan via de bestaande AL-workflow.

---

## Script vinden en op de server zetten

Het werkende script zit in de plugin:

```bash
find ~/.claude/plugins/bc-claude-plugin/scripts \
     ./.claude/plugins/bc-claude-plugin/scripts \
     ~/.local/share/claude/plugins/bc-claude-plugin/scripts \
     ~/code/bc-claude-plugin/scripts \
     -name "kmt-finsql-import.ps1" 2>/dev/null | head -1
```

Kopieer het naar de BC-server als `C:\NAVServices\CRT\kmt-finsql-import.ps1` (de work dir van het script). Voer het daar uit, niet vanaf de Mac/agent-machine. Via `/bc-runner` als de job op die Windows-host draait.

---

## Exacte aanroep

Import + compile (object-id expliciet):

```powershell
powershell -NoProfile -File C:\NAVServices\CRT\kmt-finsql-import.ps1 -ObjectFile 'D:\repos\kmt\objects\COD50070 - Native Artist Pages.txt' -Id 50070
```

Alleen compileren:

```powershell
powershell -NoProfile -File C:\NAVServices\CRT\kmt-finsql-import.ps1 -CompileOnly -Id 50062
```

`-Id` weglaten mag bij import: het script leest dan de `OBJECT`-header van het `.txt`-bestand.

### Parameters

| Parameter | Standaard | Toelichting |
|-----------|-----------|-------------|
| `-ObjectFile` | (verplicht tenzij `-CompileOnly`) | Pad naar C/SIDE `.txt` |
| `-Id` | uit `OBJECT`-header | Object-id voor compile-filter. **Gebruik dit, geen `-Filter`.** |
| `-CompileOnly` | uit | Sla import over, compileer alleen |
| `-Database` | `kmt-test` | SQL-database |
| `-Server` | `.` | SQL-server |
| `-TimeoutSec` | `90` | Kill finsql als het niet eindigt (verborgen dialoog) |
| `-Filter` | intern `Type=Codeunit;ID=<Id>` | **Niet meegeven vanuit de caller.** Zie valkuil 2. |

### Vaste paden in het script

- finsql: `C:\Program Files (x86)\Microsoft Dynamics 365 Business Central\140\RoleTailored Client\finsql.exe`
- Work dir: `C:\NAVServices\CRT` (importkopie, logs, lockfile `kmt-finsql.lock`)
- `synchronizeschemachanges=no`
- `ntauthentication=1`

---

## Harde regels (elke regel is een echte failure)

### 1. Nooit één komma-string als finsql-argumenten

PowerShell opent dan de RTC GUI en sterft met **"Text kan maximaal 47 tekens lang zijn"**.

Fout:

```powershell
# NOOIT — één string, GUI gaat open
Start-Process $FinSql -ArgumentList "command=importobjects,file=$f,database=$db,..."
```

Goed (zoals het script doet): `ArgumentList` als array van aparte `'key=value,'` tokens, korte paden (`Resolve-ShortPath` / 8.3), `ntauthentication=1`.

```powershell
$argsImport = @(
  'command=importobjects,',
  "file=$(Resolve-ShortPath $dest),",
  'importaction=overwrite,',
  'synchronizeschemachanges=no,',
  "servername=$Server,",
  "database=$Database,",
  'ntauthentication=1,',
  "logfile=$(Resolve-ShortPath $log)"
)
Start-Process -FilePath $FinSql -ArgumentList $argsImport -PassThru -WindowStyle Hidden
```

### 2. Roep aan met `-Id 50062`, nooit `-Filter "Type=Codeunit;ID=50062"`

Een puntkomma in een ongequote filter wordt door de caller gesplitst. finsql blijft dan hangen op een dialoog.

```powershell
# GOED
.\kmt-finsql-import.ps1 -ObjectFile $txt -Id 50062
.\kmt-finsql-import.ps1 -CompileOnly -Id 50062

# FOUT — semicolon splitst de command line
.\kmt-finsql-import.ps1 -CompileOnly -Filter "Type=Codeunit;ID=50062"
```

Het script bouwt het compile-filter intern. `-Id` betekent in dit script: compileer `Type=Codeunit;ID=<Id>` (KMT-codeunits).

### 3. Eén finsql tegelijk

Het script neemt een lock (`C:\NAVServices\CRT\kmt-finsql.lock`) en weigert als finsql al draait. Start geen tweede import terwijl er één loopt.

### 4. Timeout als finsql niet eindigt

Een verborgen RTC-dialoog laat finsql forever hangen. Het script wacht max `$TimeoutSec` (standaard 90s), killed het proces, en gooit. Bij exitcode ≠ 0 print het de eerste regels van de finsql-log. Laat geen hung finsql achter.

### 5. Niet `Get-Content -TotalCount` en `-Raw` combineren

```powershell
# FOUT — gooit, compile wordt overgeslagen
Get-Content $Path -TotalCount 1 -Raw
```

Het script leest de `OBJECT`-header met alleen `-TotalCount 1`.

### 6. Na import: compileer dat object-id

Import alleen is niet klaar. Het script compileert altijd na import. Zonder `-Id` komt het id uit de eerste regel (`OBJECT Codeunit 50070 …`).

### 7. Defaults niet opnieuw verzinnen

Wijzig finsql-pad, database, server of work dir niet tenzij de gebruiker dat expliciet vraagt. Standaard: BC14 RTC finsql, database `kmt-test`, server `.`, work dir `C:\NAVServices\CRT`, `synchronizeschemachanges=no`.

---

## Gerelateerde C/SIDE-valkuilen (objecttekst)

Los van finsql zelf: een import kan slagen en de compile alsnog falen.

- **Lokale variabele-id's** moeten uniek zijn binnen één procedure. Een parameter en een local mogen niet hetzelfde `@50000` delen.
- **Procedurenamen** mogen geen reserved types zijn (`Page`, `Text`, …).
- **Procedure-id's** moeten uniek zijn binnen het object.

---

## Wat je nooit doet

- Zelf `finsql.exe` aanroepen met een bedachte argumentstring
- `-Filter` met `Type=…;ID=…` vanuit PowerShell/runner/bash doorgeven
- Een tweede finsql starten “omdat de eerste lang duurt”
- Een hung finsql laten staan
- Alleen importeren zonder compile
- `Get-Content -TotalCount -Raw` gebruiken om de header te lezen
