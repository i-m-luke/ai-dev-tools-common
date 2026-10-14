# README

The repository conaints agent tools (skills, agents, etc.) bundled as a plugin.

## Skills

- Installation: Install skills at once by running 'npx skills add \<floder or git repo url\>' command
- Updating: Update the skills by 'npx skills update' command
- Docs: [docs/skills](docs/skills/index.md)
- In-progress (not shipped) tools: [docs/in-progress.md](docs/in-progress.md)

## AGENTS-SHARED

`AGENTS-SHARED.md` holds user preferences shared across projects. To use it, create a symlink binding it with instruction file for concrete harness:

**Claude Code:**

```ps
New-Item -ItemType SymbolicLink -Path ~/.claude/CLAUDE.md -Target <path-to-this-repo>/AGENTS-SHARED.md
```

**Copilot CLI:**

```ps
New-Item -ItemType SymbolicLink -Path ~/.copilot/copilot-instructions.md -Target <path-to-this-repo>/AGENTS-SHARED.md
```

## Verification

Two kinds of checks verify the repo:

- [Script tests](docs/verification/script-tests.md): Pester tests of the scripts the skills ship and of every
  skill's frontmatter. Fast and free (no token consumption), run them whenever you change a script or a skill.
- [Evals](docs/verification/evals.md): run Copilot CLI against the skills and agent instructions and grade its
  behaviour. They consume tokens, so run only the evals for what you changed.
