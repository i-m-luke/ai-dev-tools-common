# Development notes

## AGENTS-SHARED.md improvements

### MEMORY.md

- Agent may maintain a workspace-scoped MEMORY.md (in `.artifacts`)
- Before adding anything, it asks first (it never maintains the file on its own, but it must only add decisions made by the user), and whenever it uses a specific piece of knowledge, it always reports that it took it from memory
- It could ask once whether it should set up an ADR, and if not, the decision would be recorded in the memory.

## Skill changes

None

## Future skills

### browser-app-spy

- A similar skill to win-app-spy: however, instead of FlaUI, Playwright will be used to solve the same problems but for applications running in the browser

## Future MCPs

### win-app-spy

- Migrated win-app-spy skill
- One of to MCP tools will be "instructions": It will return the content of current skill.md
- The MCP description will:
  - Be based on the current skill description
  - Contain "Before use call instructions to get usage guidelines"?
- A skill has an advantage over MCP: no extension needs to be published
- Advantages of MCP:
  - token savings
  - determinism
  - Better testing: it is tested like an API
  - Tests: there will be a basic application, which is launched without rendering the UI, and basic tests are run against it
  - It will be located in the 'agent-toolkit-mcps' repo: Repo structure: src, docs, tools
