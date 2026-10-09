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
- Use wayfinder? Will probably be a bit complex (probably worth the tokens)

### browser-app-spy

- A similar skill to win-app-spy: however, instead of FlaUI, Playwright will be used to solve the same problems but for applications running in the browser
