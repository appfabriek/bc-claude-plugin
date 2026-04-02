# BcContainerHelper PowerShell Reference

Reference voor BcContainerHelper v6.x cmdlets ingedeeld per taakdomein. Canonical source: [bccontainerhelper.blob.core.windows.net](https://bccontainerhelper.blob.core.windows.net/public/latest.html).

---

## Containers & Setup

### Get-BCArtifactUrl

```powershell
# Laatste OnPrem artifact
$Url = Get-BCArtifactUrl -type OnPrem -country 'nl' -version '26' -select Latest

# Specifieke sandbox versie
$Url = Get-BCArtifactUrl -type Sandbox -country 'nl' -version '26.0' -select Latest

# Next major preview
$Url = Get-BCArtifactUrl -type Sandbox -country 'w1' -select NextMajor
```

| Parameter | Waarden | Standaard |
|-----------|---------|-----------|
| `type` | `OnPrem`, `Sandbox` | — |
| `country` | `nl`, `be`, `w1`, `us`, etc. | — |
| `version` | `26`, `26.0`, `26.0.12345.0` | Latest |
| `select` | `Latest`, `Current`, `NextMajor`, `NextMinor`, `Closest` | `Latest` |

### New-BcContainer

```powershell
$Cred = New-Object PSCredential 'admin', (ConvertTo-SecureString 'P@ssw0rd' -AsPlainText -Force)

New-BcContainer `
    -containerName 'bcdev' `
    -artifactUrl $Url `
    -credential $Cred `
    -auth NavUserPassword `
    -licenseFile 'C:\license\dev.bclicense' `
    -memoryLimit '8G' `
    -updateHosts `
    -accept_eula `
    -additionalParameters @('--env CustomSettings.ApiServicesEnabled=true')
```

| Parameter | Gebruik |
|-----------|---------|
| `artifactUrl` | Van `Get-BCArtifactUrl` |
| `credential` | Admin credentials |
| `auth` | `NavUserPassword`, `Windows`, `AAD` |
| `licenseFile` | Pad naar .bclicense/.flf |
| `memoryLimit` | Docker memory limit (bijv. `8G`) |
| `updateHosts` | Voeg container hostname toe aan hosts file |
| `additionalParameters` | Extra docker run parameters |

**Valkuil:** Zonder `memoryLimit` kan de container al het geheugen opeten.

### Remove-BcContainer

```powershell
Remove-BcContainer -containerName 'bcdev'
```

### Invoke-ScriptInBcContainer

```powershell
Invoke-ScriptInBcContainer -containerName 'bcdev' -scriptblock {
    Get-NAVServerConfiguration -ServerInstance BC
}
```

### Restart/Stop

```powershell
Restart-BcContainer -containerName 'bcdev'
Stop-BcContainer -containerName 'bcdev'
```

---

## Compileren & Publiceren

### Compile-AppInBcContainer

```powershell
Compile-AppInBcContainer `
    -containerName 'bcdev' `
    -appProjectFolder '.' `
    -appOutputFolder './output' `
    -credential $Cred `
    -EnableCodeCop `
    -EnableAppSourceCop `
    -EnableUICop `
    -EnablePerTenantExtensionCop `
    -AzureDevOps  # output in Azure DevOps/GitHub Actions formaat
```

| Parameter | Gebruik |
|-----------|---------|
| `appProjectFolder` | Map met app.json |
| `appOutputFolder` | Output voor .app file |
| `EnableCodeCop` | Code quality analyser |
| `EnableAppSourceCop` | AppSource compatibility checks |
| `AzureDevOps` | Compiler output als ##vso annotaties |
| `FailOn` | `error` (default), `warning`, `none` |

**Valkuil:** `EnableAppSourceCop` vereist een `AppSourceCop.json` met baseline app-pad.

### Compile-AppWithBcCompilerFolder

```powershell
# Zonder container — alleen compiler + symbols
$CompilerFolder = Download-BcCompilerFolder -artifactUrl $Url
Compile-AppWithBcCompilerFolder `
    -compilerFolder $CompilerFolder `
    -appProjectFolder '.' `
    -appOutputFolder './output' `
    -appSymbolsFolder './.alpackages'
```

Ideaal voor CI/CD op Linux runners (geen Docker nodig).

### Publish-BcContainerApp

```powershell
Publish-BcContainerApp `
    -containerName 'bcdev' `
    -appFile './output/MyApp.app' `
    -credential $Cred `
    -useDevEndpoint `
    -syncMode ForceSync `
    -install
```

| syncMode | Gebruik |
|----------|---------|
| `Add` | Alleen nieuwe tabellen/velden toevoegen |
| `Clean` | Clean sync — wist data! |
| `ForceSync` | Destructieve sync (dev only) |
| `Development` | Dev-modus (field renames etc.) |

**Valkuil:** `ForceSync` in productie wist data bij schema-wijzigingen. Gebruik `Add` of `Synchronize`.

### Unpublish / Uninstall

```powershell
Uninstall-BcContainerApp -containerName 'bcdev' -appName 'MyApp' -credential $Cred
Unpublish-BcContainerApp -containerName 'bcdev' -appName 'MyApp' -credential $Cred
```

### Get-BcContainerAppInfo

```powershell
Get-BcContainerAppInfo -containerName 'bcdev' -credential $Cred | Format-Table Name, Publisher, Version, IsInstalled
```

---

## Testen

### Run-TestsInBcContainer

```powershell
Run-TestsInBcContainer `
    -containerName 'bcdev' `
    -credential $Cred `
    -testSuite 'DEFAULT' `
    -testCodeunit 50150..50199 `
    -detailed `
    -XUnitResultFileName './testresults.xml' `
    -AzureDevOps  # output als test resultaten in CI
```

| Parameter | Gebruik |
|-----------|---------|
| `testSuite` | Test suite naam (default: `DEFAULT`) |
| `testCodeunit` | Codeunit ID of range |
| `testFunction` | Specifieke test functie naam |
| `extensionId` | Run tests van specifieke extensie |
| `detailed` | Gedetailleerde output per test |
| `XUnitResultFileName` | Exporteer als JUnit/XUnit XML |
| `AzureDevOps` | Output als CI test results |

### Run-AlPipeline

De all-in-one orchestratie wrapper (AL-Go):

```powershell
Run-AlPipeline `
    -pipelineName 'CI' `
    -baseFolder $ENV:GITHUB_WORKSPACE `
    -containerName 'build' `
    -credential $Cred `
    -installApps @() `
    -appFolders @('.') `
    -testFolders @('./test') `
    -artifact $Url `
    -outputFolder './output'
```

---

## Artifacts & Symbolen

### Download-Artifacts

```powershell
$Folders = Download-Artifacts -artifactUrl $Url -basePath 'C:\bcartifacts'
# Returns: database en platform folders
```

### Get-BcContainerSymbols

```powershell
# Download symbols van een running container
$SymbolsPath = Get-BcContainerSymbols -containerName 'bcdev'
```

### Extract-AppFileToFolder

```powershell
# .app uitpakken voor inspectie
Extract-AppFileToFolder -appFile './MyApp.app' -appFolder './extracted'
```

---

## AppSource & Signing

### Sign-BcContainerApp

```powershell
Sign-BcContainerApp `
    -containerName 'bcdev' `
    -appFile './output/MyApp.app' `
    -pfxFile './cert/codesign.pfx' `
    -pfxPassword (ConvertTo-SecureString 'CertP@ss' -AsPlainText -Force) `
    -timeStampServer 'http://timestamp.digicert.com'
```

**Valkuil:** Zonder `timeStampServer` verloopt de signing als het certificaat verloopt.

---

## Database & Backup

```powershell
# Backup
Backup-BcContainerDatabases -containerName 'bcdev' -bakFolder 'C:\backups'

# Export als bacpac (Azure SQL compatibel)
Export-BcContainerDatabasesAsBacpac -containerName 'bcdev' -bacpacFolder 'C:\bacpac'

# Company kopiëren
Copy-CompanyInBcContainer -containerName 'bcdev' -sourceCompanyName 'CRONUS' -destinationCompanyName 'TEST'
```

---

## Utilities

```powershell
# Bestanden kopiëren
Copy-FileToBcContainer -containerName 'bcdev' -localPath './data.xml' -containerPath 'C:\run\data.xml'
Copy-FileFromBcContainer -containerName 'bcdev' -containerPath 'C:\run\output.txt' -localPath './output.txt'

# Compiler output omzetten naar CI annotaties
Convert-AlcOutputToDevOps -alcOutput $CompileOutput -gitHubActions

# Container helper cache opschonen
Flush-ContainerHelperCache -keepDays 7

# Config
Get-BcContainerHelperConfig
Set-BcContainerHelperConfig -usePsSession $true
```

---

## AL-Go for GitHub

AL-Go is Microsoft's officiële CI/CD framework bovenop BcContainerHelper:

- Repository: [microsoft/AL-Go](https://github.com/microsoft/AL-Go)
- Gebruikt `Run-AlPipeline` als orchestratie-laag
- Levert kant-en-klare GitHub Actions workflows
- Ondersteunt multi-project repos, dependency resolution, versioning
- Settings via `.github/AL-Go-Settings.json`

### Verhouding tot BcContainerHelper

```
AL-Go for GitHub (CI/CD framework)
    └── Run-AlPipeline (orchestratie)
        └── BcContainerHelper cmdlets (individuele operaties)
            └── Docker / BcArtifacts (runtime)
```

AL-Go = hoog niveau (hele pipeline). BcContainerHelper = laag niveau (individuele cmdlets).

---

## BC Admin Center (omgevingsbeheer)

Vereist: BcContainerHelper + Azure AD app registratie met Dynamics 365 Business Central Admin Centre API permissie.

### Authenticatie

```powershell
$authContext = New-BcAuthContext `
    -tenantID "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
    -clientID "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
    -clientSecret $env:BC_CLIENT_SECRET `
    -scopes "https://api.businesscentral.dynamics.com/.default"
```

### Cmdlets

| Cmdlet | Gebruik |
|--------|---------|
| `Get-BcEnvironments` | Lijst alle omgevingen van een tenant |
| `New-BcEnvironment` | Nieuwe sandbox aanmaken |
| `Copy-BcEnvironment` | Productie kopiëren naar sandbox |
| `Remove-BcEnvironment` | Omgeving verwijderen |
| `Restart-BcEnvironment` | Server instance herstarten |
| `Get-BcPublishedApps` | Geïnstalleerde apps per omgeving |
| `Install-BcPublishedApp` | App installeren via Admin Center API |
| `Uninstall-BcPublishedApp` | App verwijderen |
| `Update-BcPublishedApp` | App updaten naar nieuwste versie |
| `Get-BcEnvironmentUpdateWindow` | Onderhoudstijdvak opvragen |
| `Set-BcEnvironmentUpdateWindow` | Onderhoudstijdvak instellen |

### Voorbeeld

```powershell
# Lijst alle omgevingen
$envs = Get-BcEnvironments -bcAuthContext $authContext
$envs | Format-Table name, type, applicationVersion

# Apps op een omgeving
$apps = Get-BcPublishedApps -bcAuthContext $authContext -environment 'production'
$apps | Where-Object publisher -ne 'Microsoft' | Format-Table name, publisher, version
```

---

## Config

```powershell
# Config locatie
# Windows: C:\ProgramData\BcContainerHelper\BcContainerHelper.config.json
# Mac/Linux: ~/.BcContainerHelper/BcContainerHelper.config.json

# Nuttige settings
Set-BcContainerHelperConfig -usePsSession $true          # Snellere container communicatie
Set-BcContainerHelperConfig -defaultContainerName 'bcdev' # Standaard container naam
Set-BcContainerHelperConfig -artifactCachePath 'D:\cache' # Artifact cache locatie
```
