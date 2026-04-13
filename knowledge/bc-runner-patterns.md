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
