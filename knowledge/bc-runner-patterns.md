# BC Runner Patterns

Kennisbank voor remote PowerShell uitvoering op OnPrem BC-servers via GitHub Actions self-hosted runners. Gebruik dit als referentie bij het schrijven van scripts voor de `/bc-runner` skill.

---

## Architectuur

```
Claude Code (lokaal)
    ↓ gh workflow run bc-runner.yaml -f script="..."
GitHub Actions API
    ↓
Self-hosted runner (cos0mb4596, Windows, X64)
    ↓ NavAdminTool / BcContainerHelper / Invoke-Sqlcmd
BC Server (localhost op de runner)
```

De runner draait op dezelfde machine als de BC-server. Alle NavAdminTool-cmdlets werken via localhost zonder authenticatie.

**Belangrijk**: Self-hosted runners kunnen 1 job tegelijk. Trigger nooit parallel.

---

## Workflow beschikbaarheid controleren

```bash
# Controleer of bc-runner.yaml aanwezig is
ls .github/workflows/bc-runner.yaml 2>/dev/null && echo "aanwezig" || echo "ontbreekt"
```

Als het ontbreekt: kopieer vanuit de plugin template:
```bash
cp ~/.claude/plugins/bc-claude-plugin/templates/bc-runner.yaml \
   .github/workflows/bc-runner.yaml
```

---

## Script triggeren

```bash
# Script naar temp bestand schrijven
cat > /tmp/bc-runner.ps1 << 'PSEOF'
# PowerShell hier
PSEOF

# Triggeren
gh workflow run bc-runner.yaml \
  -f environment="Dev (dev)" \
  -f description="Omschrijving van de actie" \
  -F script=@/tmp/bc-runner.ps1

# Wacht op run
sleep 3
RUN_ID=$(gh run list --workflow=bc-runner.yaml --limit=1 --json databaseId -q '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status

# Lees output
gh run view "$RUN_ID" --log 2>&1 | grep -A 200 "Execute script"
```

---

## NavAdminTool — Cmdlet referentie

### App informatie

```powershell
# Alle geïnstalleerde apps op een instance
Get-NAVAppInfo -ServerInstance $env:BC_INSTANCE

# Specifieke app
Get-NAVAppInfo -ServerInstance $env:BC_INSTANCE -Name "BC Plants"

# Info uit een .app bestand
Get-NAVAppInfo -Path "C:\path\to\app.app"

# Uitgebreide info (dependencies, etc.)
Get-NAVAppInfo -ServerInstance $env:BC_INSTANCE -Name "BC Plants" -Version "1.0.5.0"
```

### App lifecycle

```powershell
# Publiceren
Publish-NAVApp -ServerInstance $env:BC_INSTANCE -Path $appPath -Scope Global -SkipVerification

# Synchroniseren (schema update)
Sync-NAVApp -ServerInstance $env:BC_INSTANCE -Name "App Naam" -Version "1.0.0.0" -Tenant default -Mode Synchronize
# Of ForceSync voor destructieve wijzigingen:
Sync-NAVApp -ServerInstance $env:BC_INSTANCE -Name "App Naam" -Version "1.0.0.0" -Tenant default -Mode ForceSync

# Installeren
Install-NAVApp -ServerInstance $env:BC_INSTANCE -Name "App Naam" -Version "1.0.0.0" -Tenant default

# Data upgrade (bij versie-update)
Start-NAVAppDataUpgrade -ServerInstance $env:BC_INSTANCE -Name "App Naam" -Version "1.0.0.0" -Tenant default

# Deïnstalleren
Uninstall-NAVApp -ServerInstance $env:BC_INSTANCE -Name "App Naam" -Tenant default

# Verwijderen uit published list
Unpublish-NAVApp -ServerInstance $env:BC_INSTANCE -Name "App Naam"
```

### Server & tenant informatie

```powershell
# Alle BC service instances op deze machine
Get-NAVServerInstance

# Server configuratie (poorten, DB, etc.)
Get-NAVServerConfiguration -ServerInstance $env:BC_INSTANCE

# Specifieke instelling
(Get-NAVServerConfiguration -ServerInstance $env:BC_INSTANCE).DatabaseName

# Alle tenants
Get-NAVTenant -ServerInstance $env:BC_INSTANCE

# Tenant details
Get-NAVTenant -ServerInstance $env:BC_INSTANCE -Tenant default
```

### Server beheer

```powershell
# Instance herstarten
Restart-NAVServerInstance -ServerInstance $env:BC_INSTANCE

# Instance stoppen / starten
Stop-NAVServerInstance -ServerInstance $env:BC_INSTANCE
Start-NAVServerInstance -ServerInstance $env:BC_INSTANCE

# Configuratie wijzigen
Set-NAVServerConfiguration -ServerInstance $env:BC_INSTANCE -KeyName "MaxConcurrentCalls" -KeyValue "40"
```

### Gebruikersbeheer

```powershell
# Alle gebruikers (Windows-auth tenant)
Get-NAVServerUser -ServerInstance $env:BC_INSTANCE -Tenant default

# Gebruiker aanmaken
New-NAVServerUser -ServerInstance $env:BC_INSTANCE -Tenant default `
  -WindowsAccount "DOMAIN\username"

# Permissie set toewijzen
New-NAVServerUserPermissionSet -ServerInstance $env:BC_INSTANCE -Tenant default `
  -WindowsAccount "DOMAIN\username" -PermissionSetId "SUPER"
```

### Licentie

```powershell
# Licentie info ophalen
Get-NAVServerLicense -ServerInstance $env:BC_INSTANCE

# Licentie importeren
Import-NAVServerLicense -ServerInstance $env:BC_INSTANCE -LicenseFile "C:\path\to\license.bclicense"
```

### Codeunit uitvoeren

```powershell
# Codeunit uitvoeren (voor data-operaties)
Invoke-NAVCodeunit -ServerInstance $env:BC_INSTANCE `
  -Tenant default `
  -CodeunitId 50018 `
  -CompanyName "CRONUS"
```

---

## SQL — Invoke-Sqlcmd

Gebruik Invoke-Sqlcmd voor data-queries die niet via AL/API kunnen.

```powershell
# Database naam ophalen
$dbName = (Get-NAVServerConfiguration -ServerInstance $env:BC_INSTANCE).DatabaseName
$dbServer = (Get-NAVServerConfiguration -ServerInstance $env:BC_INSTANCE).DatabaseServer

# Query uitvoeren
$result = Invoke-Sqlcmd `
  -ServerInstance $dbServer `
  -Database $dbName `
  -Query "SELECT TOP 10 [No_], [Name] FROM [CRONUS$Customer] ORDER BY [No_]"

$result | ForEach-Object { Write-Host "$($_.'No_') — $($_.'Name')" }
```

### BC table naming in SQL

AL table name → SQL: vervang spaties door `$`, prefix met company name:
- `Customer` → `[CRONUS$Customer]`
- `Document Header` (table 50010 in extension) → `[$app-id$Document Header]` of via systeem:

```powershell
# Zoek extensie-tabellen via metadata
$tables = Invoke-Sqlcmd -ServerInstance $dbServer -Database $dbName `
  -Query "SELECT [Table Name], [Company Name] FROM [CRONUS\$\$ndo\$tenantproperty]" `
  -ErrorAction SilentlyContinue
```

Gebruik de `/diagnose` skill (AL codeunit) voor data-queries op extensie-tabellen — dat is veiliger dan SQL.

---

## BcContainerHelper

Beschikbaar op de runner voor Docker-gebaseerde omgevingen.

```powershell
# Container status
Get-BcContainers

# Geïnstalleerde apps in container
Get-BcContainerAppInfo -ContainerName "bcserver"

# App publiceren naar container
Publish-BcContainerApp -ContainerName "bcserver" -appFile "C:\path\to\app.app" -install

# Container opnieuw starten
Restart-BcContainer -ContainerName "bcserver"
```

---

## Patronen per use case

### Versie van alle apps op alle instances

```powershell
$instances = Get-NAVServerInstance | Where-Object State -eq 'Running'
foreach ($inst in $instances) {
    Write-Host "`n=== $($inst.ServerInstance) ===" -ForegroundColor Cyan
    Get-NAVAppInfo -ServerInstance $inst.ServerInstance |
        Where-Object { $_.PublishedAs -ne 'Global' -or $_.Publisher -ne 'Microsoft' } |
        Sort-Object Publisher, Name |
        ForEach-Object {
            Write-Host "  $($_.Publisher) / $($_.Name) v$($_.Version) [$($_.Status)]"
        }
}
```

### App update deployen

```powershell
$appPath = Join-Path $env:REPO_ROOT "output\MyApp_1.2.3.0.app"
$appName = "My App"
$appVersion = "1.2.3.0"
$instance = $env:BC_INSTANCE

# Publish nieuwe versie
Publish-NAVApp -ServerInstance $instance -Path $appPath -Scope Global -SkipVerification

# Sync (schema)
Sync-NAVApp -ServerInstance $instance -Name $appName -Version $appVersion -Tenant default -Mode Synchronize

# Upgrade of install
try {
    Start-NAVAppDataUpgrade -ServerInstance $instance -Name $appName -Version $appVersion -Tenant default
    Write-Host "Data upgrade succesvol"
} catch {
    Install-NAVApp -ServerInstance $instance -Name $appName -Version $appVersion -Tenant default
    Write-Host "Installatie succesvol"
}

# Verwijder oude versies
Get-NAVAppInfo -ServerInstance $instance -Name $appName |
    Where-Object { $_.Version -ne $appVersion } |
    ForEach-Object {
        try {
            Unpublish-NAVApp -ServerInstance $instance -Name $appName -Version $_.Version
            Write-Host "Oude versie verwijderd: $($_.Version)"
        } catch { }
    }
```

### Server health check

```powershell
$instances = Get-NAVServerInstance
foreach ($inst in $instances) {
    $cfg = Get-NAVServerConfiguration -ServerInstance $inst.ServerInstance
    $tenants = Get-NAVTenant -ServerInstance $inst.ServerInstance -ErrorAction SilentlyContinue
    $appCount = (Get-NAVAppInfo -ServerInstance $inst.ServerInstance -ErrorAction SilentlyContinue).Count

    Write-Host "Instance: $($inst.ServerInstance)"
    Write-Host "  Status:   $($inst.State)"
    Write-Host "  Database: $($cfg.DatabaseServer)\$($cfg.DatabaseName)"
    Write-Host "  Tenants:  $(($tenants | Measure-Object).Count)"
    Write-Host "  Apps:     $appCount"
    Write-Host ""
}
```

### Event log raadplegen

```powershell
# BC Application event log (laatste 50 errors)
Get-EventLog -LogName "Application" -Source "*Dynamics*" -EntryType Error -Newest 50 |
    Select-Object TimeGenerated, Message |
    ForEach-Object {
        Write-Host "[$($_.TimeGenerated)] $($_.Message.Substring(0, [Math]::Min(200, $_.Message.Length)))"
    }

# Of via Get-WinEvent (nieuwer, meer opties)
Get-WinEvent -ProviderName "MicrosoftDynamicsNavOrBC" -MaxEvents 20 -ErrorAction SilentlyContinue |
    Select-Object TimeCreated, LevelDisplayName, Message |
    Format-Table -AutoSize
```

### Gebruikers overzicht

```powershell
$users = Get-NAVServerUser -ServerInstance $env:BC_INSTANCE -Tenant default
$users | Select-Object UserName, State, LicenseType, FullName |
    Sort-Object UserName |
    Format-Table -AutoSize
Write-Host "Totaal: $($users.Count) gebruikers"
```

### Licentie check

```powershell
$lic = Get-NAVServerLicense -ServerInstance $env:BC_INSTANCE
Write-Host "Licentie:"
Write-Host "  Partner:    $($lic.PartnerName)"
Write-Host "  Customer:   $($lic.CustomerName)"
Write-Host "  Verloopdatum: $($lic.ExpirationDate)"
Write-Host "  Type:       $($lic.LicenseType)"

$daysLeft = ($lic.ExpirationDate - (Get-Date)).Days
if ($daysLeft -lt 30) {
    Write-Host "  WAARSCHUWING: licentie verloopt over $daysLeft dagen!" -ForegroundColor Yellow
}
```

### Dependency-volgorde bepalen voor app deployment

```powershell
# Geef de juiste publish-volgorde op basis van app dependencies
function Get-AppPublishOrder {
    param([string[]]$AppPaths)

    $apps = $AppPaths | ForEach-Object {
        $info = Get-NAVAppInfo -Path $_
        @{ Path = $_; Id = $info.AppId; Name = $info.Name; Deps = $info.Dependencies.AppId }
    }

    # Topologisch sorteren (simpel: apps zonder deps eerst)
    $ordered = @()
    $remaining = [System.Collections.ArrayList]$apps

    while ($remaining.Count -gt 0) {
        $ready = $remaining | Where-Object {
            $_.Deps.Count -eq 0 -or
            ($_.Deps | Where-Object { $remaining.Id -contains $_ }).Count -eq 0
        } | Select-Object -First 1

        if (-not $ready) { Write-Host "Kringverwijzing of onoplosbare dependency!"; break }
        $ordered += $ready
        $remaining.Remove($ready)
    }

    return $ordered
}
```

### Gepubliceerde maar niet-geïnstalleerde versies opruimen

Na elke app-update blijven oude published versies staan die niet meer geïnstalleerd zijn. Deze opruimen:

```powershell
$ErrorActionPreference = 'Stop'

$appName = "BC Plants"  # of leeg laten voor alle eigen apps

Write-Host "=== Opruimen verouderde versies op $env:BC_INSTANCE ===" -ForegroundColor Cyan

# Haal alle versies op per app
$allApps = Get-NAVAppInfo -ServerInstance $env:BC_INSTANCE
$grouped = $allApps | Group-Object Name

foreach ($group in $grouped) {
    if ($group.Count -le 1) { continue }

    # Hoogste versie = huidig; de rest mag weg als ze niet geïnstalleerd zijn
    $sorted = $group.Group | Sort-Object Version -Descending
    $current = $sorted[0]
    $obsolete = $sorted | Select-Object -Skip 1 | Where-Object { $_.Status -ne 'Installed' }

    foreach ($old in $obsolete) {
        try {
            Unpublish-NAVApp -ServerInstance $env:BC_INSTANCE -Name $old.Name -Version $old.Version
            Write-Host "  Verwijderd: $($old.Name) v$($old.Version)" -ForegroundColor Green
        } catch {
            Write-Host "  Overgeslagen: $($old.Name) v$($old.Version) — $_" -ForegroundColor Yellow
        }
    }
}
Write-Host "Klaar."
```

### Multi-omgeving configuratie vergelijken

Vergelijk server-configuratie tussen twee instances om onverwacht verschil in gedrag te verklaren:

```powershell
$ErrorActionPreference = 'Stop'

$instances = @('dev', 'pop')  # pas aan naar gewenste instances
$relevantKeys = @(
    'DatabaseServer', 'DatabaseName',
    'ClientServicesPort', 'ODataServicesPort', 'SOAPServicesPort',
    'MaxConcurrentCalls', 'MaxNumberOfConcurrentWebServiceRequests',
    'DefaultTimeZone', 'EnableDebugging',
    'ClientServicesCredentialType', 'ServicesCertificateThumbprint'
)

$configs = @{}
foreach ($inst in $instances) {
    $cfg = Get-NAVServerConfiguration -ServerInstance $inst
    $configs[$inst] = $cfg
}

Write-Host "=== Config vergelijking: $($instances -join ' vs ') ===" -ForegroundColor Cyan
Write-Host ""

foreach ($key in $relevantKeys) {
    $values = $instances | ForEach-Object { $configs[$_].$key }
    $allSame = ($values | Select-Object -Unique).Count -eq 1
    $prefix = if ($allSame) { "  " } else { "! " }
    $color = if ($allSame) { 'Gray' } else { 'Yellow' }

    Write-Host "$prefix$key" -ForegroundColor $color
    foreach ($inst in $instances) {
        Write-Host "    $inst : $($configs[$inst].$key)" -ForegroundColor $color
    }
}
```

### Database schema valideren

Controleer of het schema consistent is met de geïnstalleerde apps (nuttig vóór een upgrade of na een gefailde deploy):

```powershell
$ErrorActionPreference = 'Stop'

Write-Host "=== Schema validatie op $env:BC_INSTANCE ===" -ForegroundColor Cyan

try {
    $result = Test-NAVTenantDatabaseSchema -ServerInstance $env:BC_INSTANCE -Tenant default
    if ($result) {
        Write-Host "Schema-inconsistenties gevonden:" -ForegroundColor Yellow
        $result | ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Host "Schema is consistent — geen problemen gevonden." -ForegroundColor Green
    }
} catch {
    Write-Host "Validatie mislukt: $_" -ForegroundColor Red
}
```

### Tenant sync-status controleren

Toont of tenants klaar zijn, of ze synchronisatie of data upgrade nodig hebben:

```powershell
$ErrorActionPreference = 'Stop'

Write-Host "=== Tenant status op $env:BC_INSTANCE ===" -ForegroundColor Cyan

$tenants = Get-NAVTenant -ServerInstance $env:BC_INSTANCE
foreach ($tenant in $tenants) {
    $statusColor = switch ($tenant.State) {
        'Operational'    { 'Green' }
        'NeedsUpgrade'   { 'Yellow' }
        'UpgradePending' { 'Red' }
        default          { 'Gray' }
    }
    Write-Host "  [$($tenant.State)] $($tenant.Id) — DB: $($tenant.DatabaseName)" -ForegroundColor $statusColor
}

# Apps die data upgrade nodig hebben
$needsUpgrade = Get-NAVAppInfo -ServerInstance $env:BC_INSTANCE -Tenant default |
    Where-Object { $_.NeedsDataUpgrade -eq $true -or $_.Status -eq 'NeedsUpgrade' }

if ($needsUpgrade.Count -gt 0) {
    Write-Host ""
    Write-Host "Apps die data upgrade nodig hebben:" -ForegroundColor Yellow
    $needsUpgrade | ForEach-Object { Write-Host "  $($_.Name) v$($_.Version)" }
}
```

### Company kopiëren voor test

Maak een exacte kopie van een productie-company voor testdoeleinden, zonder backup/restore:

```powershell
$ErrorActionPreference = 'Stop'

$sourceCompany = "AVIKO BE"
$targetCompany = "AVIKO BE (TEST)"

Write-Host "=== Company kopiëren: '$sourceCompany' → '$targetCompany' ===" -ForegroundColor Cyan
Write-Host "Dit kan enkele minuten duren afhankelijk van de dataomvang..."

# Verwijder doelcompany als die al bestaat
try {
    Remove-NAVCompany -ServerInstance $env:BC_INSTANCE -Tenant default `
        -CompanyName $targetCompany -ErrorAction SilentlyContinue
    Write-Host "  Bestaande doelcompany verwijderd."
} catch { }

Copy-NAVCompany -ServerInstance $env:BC_INSTANCE -Tenant default `
    -SourceCompanyName $sourceCompany -DestinationCompanyName $targetCompany

Write-Host "  Kopie aangemaakt: $targetCompany" -ForegroundColor Green
```

### SQL backup check

Controleer wanneer de laatste succesvolle backup was — niet beschikbaar via de BC-client:

```powershell
$ErrorActionPreference = 'Stop'

$cfg = Get-NAVServerConfiguration -ServerInstance $env:BC_INSTANCE
$dbServer = $cfg.DatabaseServer
$dbName   = $cfg.DatabaseName

Write-Host "=== Backup status voor $dbName op $dbServer ===" -ForegroundColor Cyan

$backups = Invoke-Sqlcmd -ServerInstance $dbServer -Database "msdb" -Query @"
SELECT TOP 5
    bs.database_name,
    bs.type,
    bs.backup_start_date,
    bs.backup_finish_date,
    DATEDIFF(MINUTE, bs.backup_start_date, bs.backup_finish_date) AS duration_min,
    bmf.physical_device_name,
    bs.is_copy_only,
    CASE bs.type WHEN 'D' THEN 'Full' WHEN 'I' THEN 'Differential' WHEN 'L' THEN 'Log' ELSE bs.type END AS backup_type
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = '$dbName'
ORDER BY bs.backup_start_date DESC
"@

if (-not $backups) {
    Write-Host "  Geen backups gevonden voor $dbName!" -ForegroundColor Red
} else {
    $latest = $backups[0]
    $age = [Math]::Round(((Get-Date) - $latest.backup_finish_date).TotalHours, 1)
    $ageColor = if ($age -gt 24) { 'Red' } elseif ($age -gt 12) { 'Yellow' } else { 'Green' }

    Write-Host "  Laatste backup: $($latest.backup_type) — $($latest.backup_finish_date.ToString('yyyy-MM-dd HH:mm')) ($age uur geleden)" -ForegroundColor $ageColor
    Write-Host ""
    Write-Host "  Recente backups:"
    $backups | ForEach-Object {
        Write-Host "    [$($_.backup_type)] $($_.backup_start_date.ToString('MM-dd HH:mm')) — $($_.duration_min) min — $($_.physical_device_name)"
    }
}
```

### Schijfruimte en server resources

```powershell
$ErrorActionPreference = 'Stop'

Write-Host "=== Server resources op $env:COMPUTERNAME ===" -ForegroundColor Cyan

# Schijfruimte
Write-Host ""
Write-Host "Schijfruimte:"
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } | ForEach-Object {
    $total = [Math]::Round(($_.Used + $_.Free) / 1GB, 1)
    $free  = [Math]::Round($_.Free / 1GB, 1)
    $pct   = [Math]::Round($_.Used / ($_.Used + $_.Free) * 100)
    $color = if ($pct -gt 90) { 'Red' } elseif ($pct -gt 75) { 'Yellow' } else { 'Green' }
    Write-Host "  $($_.Name): $free GB vrij van $total GB ($pct% gebruikt)" -ForegroundColor $color
}

# Geheugen
Write-Host ""
Write-Host "Geheugen:"
$os = Get-CimInstance Win32_OperatingSystem
$totalMem = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
$freeMem  = [Math]::Round($os.FreePhysicalMemory / 1MB, 1)
$usedPct  = [Math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize * 100)
$memColor = if ($usedPct -gt 90) { 'Red' } elseif ($usedPct -gt 75) { 'Yellow' } else { 'Green' }
Write-Host "  $freeMem GB vrij van $totalMem GB ($usedPct% gebruikt)" -ForegroundColor $memColor

# Top processen op geheugen
Write-Host ""
Write-Host "Top 5 processen (geheugen):"
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 5 |
    ForEach-Object {
        Write-Host "  $($_.Name.PadRight(30)) $([Math]::Round($_.WorkingSet64/1MB)) MB"
    }

# BC service temp-mappen
Write-Host ""
Write-Host "BC temp-mappen:"
@('C:\temp\BCDiagnostics', 'C:\Windows\Temp', "$env:TEMP") | ForEach-Object {
    if (Test-Path $_) {
        $size = [Math]::Round((Get-ChildItem $_ -Recurse -ErrorAction SilentlyContinue |
            Measure-Object Length -Sum).Sum / 1MB, 1)
        Write-Host "  $_ : $size MB"
    }
}
```

### Encryptiesleutel exporteren

Essentieel bij server-migraties — zonder de sleutel zijn versleutelde velden onleesbaar na restore:

```powershell
$ErrorActionPreference = 'Stop'

$exportPath = "C:\temp\bc-encryption-key-$(Get-Date -Format 'yyyyMMdd').key"

Write-Host "=== Encryptiesleutel exporteren van $env:BC_INSTANCE ===" -ForegroundColor Cyan
Write-Host "Uitvoerpad: $exportPath"

Export-NAVEncryptionKey -ServerInstance $env:BC_INSTANCE -KeyPath $exportPath -Force
Write-Host "Sleutel geëxporteerd." -ForegroundColor Green
Write-Host ""
Write-Host "BELANGRIJK: Bewaar dit bestand op een veilige locatie buiten de server."
Write-Host "Verwijder het exportbestand na overdracht:"
Write-Host "  Remove-Item '$exportPath'"
```

### Windows services status

Snel overzicht van BC-gerelateerde services:

```powershell
$ErrorActionPreference = 'Stop'

Write-Host "=== Windows services op $env:COMPUTERNAME ===" -ForegroundColor Cyan

$servicePatterns = @('*MicrosoftDynamicsNAV*', '*BusinessCentral*', 'MSSQL*', 'SQLAgent*')
$services = $servicePatterns | ForEach-Object { Get-Service -Name $_ -ErrorAction SilentlyContinue } |
    Sort-Object DisplayName

foreach ($svc in $services) {
    $color = if ($svc.Status -eq 'Running') { 'Green' } elseif ($svc.Status -eq 'Stopped') { 'Red' } else { 'Yellow' }
    Write-Host "  [$($svc.Status.ToString().PadRight(8))] $($svc.DisplayName)" -ForegroundColor $color
}
```

---

## Output structuur

Schrijf altijd gestructureerde output voor gemakkelijk parsen:

```powershell
# Gebruik Write-Host voor leesbare output
Write-Host "=== RESULTAAT ===" -ForegroundColor Green
Write-Host "app_name=$appName"
Write-Host "app_version=$appVersion"
Write-Host "status=installed"
Write-Host "================="

# Of als JSON
$result = @{
    status  = 'OK'
    apps    = @()
    message = ''
}
$result | ConvertTo-Json -Depth 5
```

---

## Veiligheidregels

- Gebruik `$ErrorActionPreference = 'Stop'` voor fail-fast gedrag
- Wrap destructieve acties in try/catch met duidelijke foutmeldingen
- Gebruik `-WhatIf` parameter bij test-runs (Uninstall, Remove, etc.)
- Bevestig altijd de juiste `$instance` vóór destructieve wijzigingen
- ForceSync = schema-destructief — alleen als de CLAUDE.md het voor die omgeving toestaat
- Steenderen en Dev gebruiken ForceSync in de plants-omgeving; andere omgevingen: Synchronize
