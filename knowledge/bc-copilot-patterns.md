# BC Copilot Patterns

Patronen voor het bouwen van AI Copilot capabilities in Business Central (System.AI module, beschikbaar vanaf BC23+).

---

## System.AI Namespace

| Type | Gebruik |
|------|---------|
| `AzureOpenAI` | Proxy naar Azure OpenAI — handelt auth en throttling |
| `AOAIChatCompletionParams` | Temperature, max tokens, top_p |
| `AOAIChatMessages` | System + user + assistant berichten |
| `AOAIOperationResponse` | Response wrapper met status en content |
| `CopilotCapability` | Registratie van jouw capability |
| `CopilotNotAvailable` | Error enum als Copilot is uitgeschakeld |

---

## Capability Registratie

### Install Codeunit

```al
codeunit 50200 "MYAPP Copilot Install"
{
    Subtype = Install;
    Access = Internal;

    trigger OnInstallAppPerCompany()
    begin
        RegisterCapability();
    end;

    local procedure RegisterCapability()
    var
        CopilotCapability: Codeunit "Copilot Capability";
        LearnMoreUrl: Text;
    begin
        LearnMoreUrl := 'https://learn.microsoft.com/myapp/copilot';

        if not CopilotCapability.IsCapabilityRegistered(Enum::"Copilot Capability"::"MYAPP Suggest Lines") then
            CopilotCapability.RegisterCapability(
                Enum::"Copilot Capability"::"MYAPP Suggest Lines",
                Enum::"Copilot Availability"::Preview,
                LearnMoreUrl);
    end;
}
```

### Upgrade Codeunit (herhaal registratie)

```al
codeunit 50201 "MYAPP Copilot Upgrade"
{
    Subtype = Upgrade;
    Access = Internal;

    trigger OnUpgradePerCompany()
    var
        CopilotCapability: Codeunit "Copilot Capability";
    begin
        if not CopilotCapability.IsCapabilityRegistered(Enum::"Copilot Capability"::"MYAPP Suggest Lines") then
            CopilotCapability.RegisterCapability(
                Enum::"Copilot Capability"::"MYAPP Suggest Lines",
                Enum::"Copilot Availability"::Preview,
                'https://learn.microsoft.com/myapp/copilot');
    end;
}
```

### Capability Enum Extension

```al
enumextension 50200 "MYAPP Copilot Capabilities" extends "Copilot Capability"
{
    value(50200; "MYAPP Suggest Lines")
    {
        Caption = 'Suggest Lines';
    }
}
```

---

## Availability Levels

| Level | Betekenis |
|-------|-----------|
| `Preview` | Opt-in, admin moet activeren via Copilot & AI page |
| `GA` | Standaard beschikbaar, admin kan uitschakelen |

---

## AzureOpenAI Aanroep

```al
codeunit 50202 "MYAPP Copilot Suggest"
{
    Access = Internal;

    procedure GenerateSuggestion(InputText: Text): Text
    var
        AzureOpenAI: Codeunit "Azure OpenAI";
        ChatMessages: Codeunit "AOAIChatMessages";
        ChatParams: Codeunit "AOAIChatCompletionParams";
        OperationResponse: Codeunit "AOAIOperationResponse";
        CopilotCapability: Codeunit "Copilot Capability";
    begin
        if not AzureOpenAI.IsEnabled(Enum::"Copilot Capability"::"MYAPP Suggest Lines") then
            exit('');

        // Authorization — BC handelt dit automatisch via het platform
        AzureOpenAI.SetAuthorization(
            Enum::"AOAI Model Type"::"Chat Completions",
            Enum::"Copilot Capability"::"MYAPP Suggest Lines");
        AzureOpenAI.SetCopilotCapability(Enum::"Copilot Capability"::"MYAPP Suggest Lines");

        // Parameters
        ChatParams.SetMaxTokens(2048);
        ChatParams.SetTemperature(0.2);

        // System message (metaprompt)
        ChatMessages.AddSystemMessage(GetSystemPrompt());

        // User message
        ChatMessages.AddUserMessage(InputText);

        // Aanroep
        AzureOpenAI.GenerateChatCompletion(ChatMessages, ChatParams, OperationResponse);

        if not OperationResponse.IsSuccess() then
            Error(OperationResponse.GetError());

        exit(ChatMessages.GetLastMessage());
    end;

    local procedure GetSystemPrompt(): Text
    begin
        exit('You are a Business Central assistant. ' +
             'Given a description of sales lines needed, suggest item numbers, quantities and unit prices. ' +
             'Return results as JSON array with fields: itemNo, description, quantity, unitPrice. ' +
             'Only suggest items that exist in the system.');
    end;
}
```

---

## PromptDialog Page

```al
page 50202 "MYAPP Copilot Suggest Lines"
{
    PageType = PromptDialog;
    Caption = 'Suggest Sales Lines with Copilot';
    IsPreview = true;
    Extensible = false;

    // PromptDialog properties
    PromptMode = Prompt; // of: Generate, Content

    layout
    {
        area(Prompt)
        {
            field(UserInput; UserInputText)
            {
                Caption = 'What lines do you need?';
                MultiLine = true;
                ApplicationArea = All;

                trigger OnValidate()
                begin
                    CurrPage.Update();
                end;
            }
        }
        area(Content)
        {
            part(SuggestionsPart; "MYAPP Copilot Suggestions Sub")
            {
                Caption = 'Suggested Lines';
                ApplicationArea = All;
            }
        }
    }

    actions
    {
        area(SystemActions)
        {
            systemaction(Generate)
            {
                Caption = 'Generate';
                ToolTip = 'Generate suggestions based on your input';

                trigger OnAction()
                begin
                    GenerateSuggestions();
                end;
            }
            systemaction(OK)
            {
                Caption = 'Keep it';
                ToolTip = 'Accept the suggested lines';
            }
            systemaction(Cancel)
            {
                Caption = 'Discard';
                ToolTip = 'Discard suggestions';
            }
            systemaction(Regenerate)
            {
                Caption = 'Regenerate';
                ToolTip = 'Generate new suggestions';

                trigger OnAction()
                begin
                    GenerateSuggestions();
                end;
            }
        }
    }

    var
        UserInputText: Text;

    local procedure GenerateSuggestions()
    var
        CopilotSuggest: Codeunit "MYAPP Copilot Suggest";
        Response: Text;
    begin
        Response := CopilotSuggest.GenerateSuggestion(UserInputText);
        // Parse JSON response en vul suggestions subpage
    end;
}
```

---

## Metaprompt Best Practices

1. **Doel:** begin met een duidelijke rol en taak
2. **Constraints:** definieer wat het model NIET mag doen
3. **Output format:** specificeer JSON-structuur voor gestructureerde output
4. **Grounding:** verwijs naar specifieke BC-entiteiten (items, klanten, etc.)
5. **Voorbeelden:** geef 1-2 voorbeelden van gewenst input/output
6. **Safety:** voeg instructie toe om geen gevoelige data te genereren

---

## Billing Types

| Type | Wanneer |
|------|---------|
| Microsoft Billed | Microsoft factureert Copilot-gebruik via BC license |
| Custom Billed | Jij factureert zelf — vereist eigen Azure OpenAI resource |

**Beslisboom:**
- AppSource app → Microsoft Billed (aanbevolen)
- PTE met eigen Azure resource → Custom Billed
- PTE zonder eigen resource → Microsoft Billed

---

## Governance

- **Transparantie:** toon altijd dat content AI-gegenereerd is
- **Opt-in:** admin moet capability activeren via Copilot & AI Capabilities page
- **Data scope:** verwerk alleen data uit de huidige company/tenant
- **Audit trail:** log Copilot-gebruik via `Session.LogMessage` (zie bc-telemetry-patterns.md)
- **Grounding:** valideer AI-output tegen bestaande BC-data vóór presentatie
