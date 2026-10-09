# Development notes

## Future skills

### win-app-spy

- C# script + FlaUI!
- The debugger agent will create ad-hoc scripts whenever interaction/state inspection is needed (screenshot, UI state)
- When necessary, add a unique identifier to the UI (e.g. AutId): However, primarily try to find access through "paths"
- Describe instructions on how to run .csx scripts
- Attach .csx templates: FlaUI application initialization, print necessary info to output (so the agent can read it), etc.
- Describe basic usage of FlaUI
- IS THIS A GENERAL (AGNOSTIC) skill: FlaUI can be used for any Windows app
- If initialization is needed: At the start, the agent will launch a Terminal.Gui app via a "script" and from the process output the agent will obtain the necessary configuration (data into DEVNOTES)
- v1: FlaUI , v2: Čisté UIA, v3: Použít yaml namísto json? Údajně lepší optimalizace, ale po migraci na MCP horší parsování?

#### Zmigorvat win-app-spy do MCP serveru

- Jeden tool bude "instructions"
- Navrátí obsah skill.md
- V Description bude: "Before use call instructions to get usage guidelines"?
- Skill má výhodu oproti MCP: Nemusí se vydávat extension
- Výhody MCP:
  - úspora tokenů
  - determinističnost
  - Lepší testování: Testuje se jako API
  - Testy: Bude existovat základní aplikace, ta se spustí bez vykreslení UI a provedou se na ni základní testy
  - Bude se nacházet v 'agent-toolkit-mcps' repo: Repo sturktura: src, docs, tools

### browser-app-spy

- A similar skill to win-app-spy: however, instead of FlaUI, Playwright will be used to solve the same problems but for applications running in the browser
