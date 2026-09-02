# macOS AL-compiler (`alc`)

Geldt voor elk AL-project op een Mac. Lees dit vóór je concludeert dat een
build onmogelijk is.

## `alc` draait op macOS

`alc` is een .NET **Core**-tool en bundelt zijn eigen runtime. Compileren
van AL op macOS kan. Zeg dat nooit af omdat er .NET-interop-errors
verschijnen.

Referenties naar .NET **Framework**-only types falen **permanent** op macOS
en compileren wél op de Windows build-server. Bekende voorbeelden:

- `System.Drawing.Bitmap`
- `System.CodeDom.*`
- `Microsoft.CSharp.CSharpCodeProvider`

## Differentieel oordelen

Vergelijk de error-set met een schone baseline (`git stash` → build →
vergelijk, of een projectscript zoals `compile-mac.sh` in BC Plants).
Alleen **nieuwe** errors horen bij jouw wijziging. Een onveranderde set
bekende interop-errors is schoon.

## Compiler vinden

```bash
ALC=$(find ~/.vscode/extensions -path "*/ms-dynamics-smb.al-*/bin/darwin/alc" 2>/dev/null | sort -V | tail -1)
```

- Lees `al.assemblyProbingPaths` uit `.vscode/settings.json` — alleen paden
  die bestaan (`test -d`).
- `.alpackages/` moet platform symbols en dependency apps bevatten.

Projectspecifieke buildcommando's (plants `compile-mac.sh`, connections
`alc`-regel in `AGENTS.md`) gaan boven dit generieke commando.

## Publiceren naar een BC-dev-endpoint

Stel URL samen uit `launch.json` (`server`, `serverInstance`, `tenant`).
Altijd multipart `-F`, nooit `--data-binary` (HTTP 415). ForceSync voor
dev, Synchronize voor accept. Credentials uit `launch.json` of de
omgeving — niet hardcoden in docs of commits.

## Remote diagnostics

Als de repo `bc-diagnostic.yaml` heeft: skill `/diagnose` of
`gh workflow run bc-diagnostic.yaml`. Body is een
`Execute(var pCduResult: Codeunit "Diagnostic Result")`.

## Oplevering

Geen AL-wijziging teruggeven zonder compile-check (differentieel op
macOS). Bij "maak PR": nieuwe branch, commit, `git push -u`, `gh pr create`.
Mergen alleen als de gebruiker dat expliciet vraagt.
