---
name: bc-ps
description: Generate BcContainerHelper PowerShell scripts from task descriptions
bc-version: ">=14.0"
---

# BC PowerShell

Vind snel de juiste BcContainerHelper cmdlet en genereer een kant-en-klaar PowerShell script.

## Input

$ARGUMENTS — taak-omschrijving in gewoon Nederlands:
- "maak een container met de laatste BC26 sandbox artifact"
- "publiceer mijn app naar de test container met ForceSync"
- "draai alle tests in codeunit 50100 en exporteer JUnit XML"
- "sign mijn app met een PFX certificaat"
- "download alle geïnstalleerde apps van productie omgeving"
- "backup de database van mijn dev container"

## Instructies

### Stap 0 — Laad kennis

1. Lees `knowledge/bc-powershell.md` volledig — dit is de primaire kennisbasis.
2. Lees `knowledge/bc-devops-patterns.md` voor CI/CD context.
3. Als relevant: lees `app.json` en `launch.json` voor project-specifieke waarden.

### Stap 1 — Analyseer de taak

Bepaal uit de beschrijving:
- **Welke cmdlet(s):** match tegen de categorieën in `bc-powershell.md`
- **Parameters:** leid af uit de context (container naam, versie, etc.)
- **Volgorde:** sommige taken vereisen meerdere cmdlets in volgorde

### Stap 2 — Genereer PowerShell script

Schrijf een compleet, uitvoerbaar script:

```powershell
# <Beschrijving van wat het script doet>

# Parameters
$ContainerName = 'bcdev'
$Credential = New-Object PSCredential 'admin', (ConvertTo-SecureString 'P@ssw0rd' -AsPlainText -Force)

# Stap 1: ...
# Stap 2: ...
```

**Regels voor het script:**
- Altijd variabelen bovenaan definiëren (makkelijk aanpasbaar)
- `$Credential` altijd als variabele, niet inline
- Error handling met `try/catch` bij kritieke operaties
- Comments per stap
- Gebruik `Write-Host` voor voortgang

### Stap 3 — Rapporteer

Toon:
- Het script (kant-en-klaar)
- Korte uitleg per cmdlet die gebruikt wordt
- Vereisten (BcContainerHelper module, Docker, etc.)
- Waarschuwingen (bijv. `ForceSync` wist data)

## Veelvoorkomende taken

### Container aanmaken

```powershell
$ArtifactUrl = Get-BCArtifactUrl -type Sandbox -country 'nl' -version '26' -select Latest
$Cred = New-Object PSCredential 'admin', (ConvertTo-SecureString 'P@ssw0rd' -AsPlainText -Force)

New-BcContainer `
    -containerName 'bcdev' `
    -artifactUrl $ArtifactUrl `
    -credential $Cred `
    -auth NavUserPassword `
    -memoryLimit '8G' `
    -updateHosts `
    -accept_eula
```

### App publiceren

```powershell
Publish-BcContainerApp `
    -containerName 'bcdev' `
    -appFile './output/MyApp.app' `
    -credential $Cred `
    -useDevEndpoint `
    -syncMode ForceSync `
    -install
```

### Tests draaien

```powershell
Run-TestsInBcContainer `
    -containerName 'bcdev' `
    -credential $Cred `
    -testCodeunit 50150 `
    -detailed `
    -XUnitResultFileName './testresults.xml'
```

### App signen

```powershell
Sign-BcContainerApp `
    -containerName 'bcdev' `
    -appFile './output/MyApp.app' `
    -pfxFile './cert/codesign.pfx' `
    -pfxPassword (ConvertTo-SecureString 'CertP@ss' -AsPlainText -Force) `
    -timeStampServer 'http://timestamp.digicert.com'
```

## Regels

- ALTIJD `knowledge/bc-powershell.md` raadplegen voor cmdlet details
- ALTIJD credentials als variabele, nooit hardcoded
- ALTIJD `memoryLimit` instellen bij `New-BcContainer`
- ALTIJD `timeStampServer` bij `Sign-BcContainerApp`
- Waarschuw bij destructieve operaties (ForceSync, Clean, Remove)
