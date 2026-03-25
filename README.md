# bc-claude-plugin

Claude Code plugin met skills voor BC AL-ontwikkeling.

## Skills

| Commando | Doel |
|----------|------|
| `/dev-publish` | Compileer en publiceer AL-app naar BC dev server |
| `/diagnose` | Voer remote AL-diagnostic uit via GitHub Actions |

## Installatie

```bash
# Voeg toe als marketplace
/plugin add-marketplace github:AppfabriekBV/bc-claude-plugin

# Installeer de skills
/plugin install dev-publish@bc-claude-plugin
/plugin install diagnose@bc-claude-plugin
```

Of lokaal (zonder GitHub):
```bash
/plugin install /Users/geert/code/bc-claude-plugin
```

---

## .NET Framework reference assemblies (macOS)

De AL compiler op macOS heeft .NET Framework 4.7.2 reference DLLs nodig voor types als `System.IO.File`, `System.Net.WebClient` etc. Deze zitten **niet** in de AL extensie zelf (die heeft alleen .NET Core DLLs).

### Eenmalige setup

**Optie A — NuGet (aanbevolen, ~42MB):**
```bash
# Installeer de ref assemblies via NuGet CLI
DEST=~/code/bc-claude-plugin/netframework-ref
mkdir -p "$DEST"
cd /tmp && curl -sL https://dist.nuget.org/win-x86-commandline/latest/nuget.exe -o nuget.exe
# Of via dotnet:
dotnet tool install -g dotnet-nuget 2>/dev/null || true
nuget install Microsoft.NETFramework.ReferenceAssemblies.net472 -OutputDirectory /tmp/netref
cp -r /tmp/netref/Microsoft.NETFramework.ReferenceAssemblies.net472.*/build/.NETFramework/v4.7.2 "$DEST/"
```

**Optie B — Kopieer van bestaand project:**
Als een collega de map al heeft (bijv. `bc plants/.netframework-ref/extracted/build/.NETFramework/v4.7.2`):
```bash
cp -r "<collega>/v4.7.2" ~/code/bc-claude-plugin/netframework-ref/v4.7.2
```

### Resultaat

```
~/code/bc-claude-plugin/netframework-ref/v4.7.2/
├── mscorlib.dll          ← System.IO.File, System.Text.Encoding, etc.
├── System.dll            ← System.Net.WebClient (incl. Headers, UploadValues)
├── System.Web.dll        ← System.Web.HttpUtility
├── Facades/              ← type-forwarders
└── ...136 DLLs totaal
```

### AL project configureren

Voeg toe aan `.vscode/settings.json` van elk AL-project:
```json
{
    "al.assemblyProbingPaths": [
        "/Users/JOUW_NAAM/code/bc-claude-plugin/netframework-ref/v4.7.2",
        "/Users/JOUW_NAAM/code/bc-claude-plugin/netframework-ref/v4.7.2/Facades"
    ]
}
```

> **Tip:** Zet dit pad ook in `CLAUDE.md` van het project, dan gebruikt `/dev-publish` het automatisch.

### .gitignore

De `netframework-ref/` map is gitignored (binary DLLs, 42MB):
```
netframework-ref/
```

Collega's moeten de setup eenmalig zelf uitvoeren.

---

## dotnet.al — assembly declaraties

Gebruik de klassieke .NET Framework assembly-namen (werken met de 4.7.2 refs):

```al
dotnet
{
    assembly("mscorlib")
    {
        type("System.Text.Encoding"; "System.Text.Encoding") {}
        type("System.Convert"; "System.Convert") {}
        type("System.String"; "System.String") {}
        type("System.IO.StreamReader"; "System.IO.StreamReader") {}
        type("System.IO.File"; "System.IO.File") {}
        type("System.Exception"; "System.Exception") {}
    }
    assembly("System")
    {
        type("System.Uri"; "System.Uri") {}
        type("System.Net.WebClient"; "System.Net.WebClient") {}
        type("System.Net.WebException"; "System.Net.WebException") {}
        type("System.Net.HttpWebResponse"; "System.Net.HttpWebResponse") {}
        type("System.Collections.Specialized.NameValueCollection"; "System.Collections.Specialized.NameValueCollection") {}
    }
    assembly("System.Web")
    {
        type("System.Web.HttpUtility"; "System.Web.HttpUtility") {}
    }
}
```

> **Waarom niet .NET Core assembly-namen?** .NET Core splits types over tientallen aparte assemblies (`System.IO.FileSystem`, `System.Net.WebClient`, etc.). Zodra je één .NET Core DLL laadt, breekt de resolutie van andere types (WebClient verliest Headers/UploadValues). Met de 4.7.2 refs werkt alles gewoon.
