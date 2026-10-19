# Development notes

## AGENTS-SHARED.md improvements

### MEMORY.md

- Agent may maintain a workspace-scoped MEMORY.md (in `.artifacts`)
- Before adding anything, it asks first (it never maintains the file on its own, but it must only add decisions made by the user), and whenever it uses a specific piece of knowledge, it always reports that it took it from memory
- It could ask once whether it should set up an ADR, and if not, the decision would be recorded in the memory.

## Skill changes

None

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

#### Migrate win-app-spy to an MCP server

- One tool will be "instructions"
- It will return the content of skill.md
- The Description will say: "Before use call instructions to get usage guidelines"?
- A skill has an advantage over MCP: no extension needs to be published
- Advantages of MCP:
  - token savings
  - determinism
  - Better testing: it is tested like an API
  - Tests: there will be a basic application, which is launched without rendering the UI, and basic tests are run against it
  - It will be located in the 'agent-toolkit-mcps' repo: Repo structure: src, docs, tools

### browser-app-spy

- A similar skill to win-app-spy: however, instead of FlaUI, Playwright will be used to solve the same problems but for applications running in the browser
