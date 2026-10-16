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

Three kinds of checks verify the repo:

- [Repository checks](docs/verification/repository-checks.md): Pester tests of the skill conventions (frontmatter,
  folder structure) and of the repo's tools. Fast and free (no token consumption); the pre-commit hook and CI run them.
- [Script tests](docs/verification/script-tests.md): Pester tests of the scripts the skills ship, run through Vitest
  (`npm run script-tests`). Free, but they
  drive real apps and services, so neither the hook nor CI runs them; run them whenever you change a script.
- [Evals](docs/verification/evals.md): run Copilot CLI against the skills and agent instructions and grade its
  behaviour (`npm run evals`). They consume tokens, so run only the evals for what you changed.
