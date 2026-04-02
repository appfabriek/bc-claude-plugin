# BC DevOps Patterns

Patronen voor CI/CD pipelines, app signing en deployment van BC extensions.

---

## GitHub Actions — AL Build Workflow

```yaml
name: Build and Test AL App

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  BC_VERSION: "24"
  APP_NAME: "MyApp"

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Download BC artifacts
        uses: microsoft/AL-Go-Actions/DetermineArtifactUrl@v5.2
        with:
          artifact: "////${{ env.BC_VERSION }}.0/w1/base"

      - name: Build AL app
        uses: microsoft/AL-Go-Actions/Build@v5.2
        with:
          project: "."
          artifactUrl: ${{ steps.determine.outputs.artifactUrl }}

      - name: Run AL tests
        uses: microsoft/AL-Go-Actions/RunTests@v5.2
        with:
          project: "."
          testCodeunit: "50150..50199"

      - name: Upload app artifact
        uses: actions/upload-artifact@v4
        with:
          name: app
          path: "**/*.app"
```

---

## AL-Go for GitHub (Microsoft Aanbevolen)

Het officiële Microsoft framework voor BC CI/CD. Setup:

```bash
# Initialiseer AL-Go in je repo
gh repo clone microsoft/AL-Go-Actions
# Kopieer templates naar .github/workflows/
```

### Standaard Workflows

| Workflow | Trigger | Doel |
|----------|---------|------|
| `CI/CD` | Push/PR | Build, test, deploy |
| `Create Release` | Manual | Versie taggen en release |
| `Publish to Environment` | Manual | Deploy naar specifieke env |
| `Update AL-Go System Files` | Scheduled | Framework updaten |

---

## BcContainerHelper (Windows Runner)

```yaml
jobs:
  build:
    runs-on: windows-latest

    steps:
      - uses: actions/checkout@v4

      - name: Install BcContainerHelper
        shell: pwsh
        run: |
          Install-Module BcContainerHelper -Force -AllowClobber

      - name: Create BC container
        shell: pwsh
        run: |
          $params = @{
            containerName = 'bcbuild'
            artifactUrl = Get-BCArtifactUrl -type OnPrem -version "${{ env.BC_VERSION }}" -country 'w1'
            auth = 'NavUserPassword'
            credential = (New-Object PSCredential 'admin', (ConvertTo-SecureString 'P@ssw0rd' -AsPlainText -Force))
            accept_eula = $true
            isolation = 'hyperv'
          }
          New-BcContainer @params

      - name: Compile app
        shell: pwsh
        run: |
          Compile-AppInBcContainer -containerName 'bcbuild' -appProjectFolder '.' -appOutputFolder './output'

      - name: Run tests
        shell: pwsh
        run: |
          Run-TestsInBcContainer -containerName 'bcbuild' -testCodeunit '50150..50199'

      - name: Remove container
        if: always()
        shell: pwsh
        run: Remove-BcContainer -containerName 'bcbuild'
```

---

## App Signing

### Azure Key Vault

```yaml
      - name: Sign app
        shell: pwsh
        run: |
          $pfxCert = [Convert]::FromBase64String('${{ secrets.CODE_SIGNING_CERT }}')
          $pfxPath = Join-Path $env:TEMP 'codesign.pfx'
          [IO.File]::WriteAllBytes($pfxPath, $pfxCert)

          Sign-BcContainerApp `
            -containerName 'bcbuild' `
            -appFile './output/MyApp.app' `
            -pfxFile $pfxPath `
            -pfxPassword (ConvertTo-SecureString '${{ secrets.PFX_PASSWORD }}' -AsPlainText -Force)
```

### Self-Signed (Ontwikkeling)

```powershell
$cert = New-SelfSignedCertificate -Subject "CN=MyApp Dev" -Type CodeSigningCert -CertStoreLocation "Cert:\CurrentUser\My"
Export-PfxCertificate -Cert $cert -FilePath "devcert.pfx" -Password (ConvertTo-SecureString "P@ss" -AsPlainText -Force)
```

---

## Environment Matrix

```yaml
jobs:
  deploy:
    strategy:
      matrix:
        include:
          - environment: dev
            server: "https://rzdm2"
            instance: "bc270"
            syncMode: "ForceSync"
          - environment: test
            server: "https://rzdm2"
            instance: "bc270-test"
            syncMode: "Synchronize"
    
    steps:
      - name: Deploy to ${{ matrix.environment }}
        run: |
          curl -sk -X POST \
            "${{ matrix.server }}:7049/${{ matrix.instance }}/dev/apps?tenant=default&SchemaUpdateMode=${{ matrix.syncMode }}" \
            -u "${{ secrets.BC_USER }}:${{ secrets.BC_PASSWORD }}" \
            -F "file=@./output/MyApp.app;type=application/octet-stream"
```

---

## PR Gate met BC Review

```yaml
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Get changed AL files
        id: changed
        run: |
          FILES=$(git diff --name-only origin/main...HEAD | grep '\.al$' | tr '\n' ' ')
          echo "files=$FILES" >> $GITHUB_OUTPUT

      - name: AL code review
        if: steps.changed.outputs.files != ''
        run: |
          echo "Changed files: ${{ steps.changed.outputs.files }}"
          # Trigger /bc-review via Claude Code CLI
```

---

## Dependency Cache

```yaml
      - name: Cache .alpackages
        uses: actions/cache@v4
        with:
          path: .alpackages
          key: alpackages-${{ hashFiles('app.json') }}
          restore-keys: alpackages-
```

---

## Secrets Management

| Secret | Gebruik |
|--------|---------|
| `BC_USER` | BC server username |
| `BC_PASSWORD` | BC server password |
| `CODE_SIGNING_CERT` | Base64-encoded PFX certificaat |
| `PFX_PASSWORD` | PFX wachtwoord |
| `AZURE_TENANT_ID` | Azure tenant voor SaaS deployment |
| `AZURE_CLIENT_ID` | Azure app registration |
| `AZURE_CLIENT_SECRET` | Azure app secret |

---

## Deployment naar SaaS

```yaml
      - name: Publish to Business Central Online
        shell: pwsh
        run: |
          $authContext = New-BcAuthContext `
            -clientId '${{ secrets.AZURE_CLIENT_ID }}' `
            -clientSecret (ConvertTo-SecureString '${{ secrets.AZURE_CLIENT_SECRET }}' -AsPlainText -Force) `
            -tenantId '${{ secrets.AZURE_TENANT_ID }}'

          Publish-PerTenantExtensionApps `
            -bcAuthContext $authContext `
            -environment 'sandbox' `
            -appFiles @('./output/MyApp.app') `
            -schemaSyncMode 'Add'
```
