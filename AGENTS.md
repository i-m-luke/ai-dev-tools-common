# Agents

## Shipped skills

A skill folder holds only what the invoking agent needs; an agent may read any file in it. Put
notes for humans (maintainers, setup) in `docs/skills/<skill>.md`, never a README in the skill folder,
and list the doc in `docs/skills/index.md`.

Before writing or editing a skill, run `/skill-writing`, then read
[`docs/guidelines/skills.md`](docs/guidelines/skills.md) for this repo's additions.

## Changes

## Code changes

### Build

Build with `dotnet build`, except `Zat.SystemTest.Toolkit.Extension` — the VSIX needs `msbuild`.

### Commit subject

Write the subject in format `< prefix > - < file-name >: < imperative-summary >`:

- **< prefix >**: Is required. Supports one of these options: a. `Feat`: for a new capability; b. `Fix`: for a defect; c. `Change`: for reworked behaviour; d. `Dev`: for work that leaves behaviour intact (refactoring, docs, warnings, tooling)
- **< file-name >**: Name the single edited production file; use it when the change touches that one
  production file and the tests it drove, drop this part otherwise.

### Versioning

On finishing work that changes shipped plugin content (`skills/`, `agents/`), recommend a semver bump level for `version` in `.plugin/plugin.json`; apply it once the user approves. If the user declines, leave `version` unchanged and don't ask again for the same change set.

- **major** — breaking change to a skill's or agent's interface (rename, removal, changed invocation).
- **minor** — new skill or agent, or a new capability in an existing one.
- **patch** — fix or wording tweak to existing content.
