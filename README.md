# README

- The agent tools (skills, agents, etc.) are bundled as a plugin

## Skills

- Installation: Install skills at once by running 'npx skills add \<floder or git repo url\>' command
- Updating: Update the skills by 'npx skills update' command

## Evals

- Run all evals: `./tools/evals.ps1`

### Requirements

- PowerShell 7+ (`pwsh`)
- Copilot CLI (`copilot`) on PATH, logged in, and allowed by your Copilot policy (https://github.com/settings/copilot)
- `evals.config.json` in the repo root (see below)

### Configuration

`evals.config.json` (git-ignored) must exist; it may be empty. Its optional `githubUser` picks the
GitHub account whose Copilot the evals use, so the right seat is used even when you have several
accounts or `GH_TOKEN` is set for another one:

```json
{ "githubUser": "your-github-login" }
```

Evals read it through `evals/utils/read-config.ps1`, which returns the file's values and stops the
eval when the file is missing or not valid JSON. With `githubUser` set, an eval takes the account's
token from GitHub CLI (`gh`, the account must be logged in via `gh auth login`) and hands it to
Copilot CLI (via `COPILOT_GITHUB_TOKEN`, for the eval's process only); without it, Copilot CLI picks
its credentials as usual. A `githubUser` not logged in to `gh` stops the eval too.

### agents-shared-symlink

`evals/agents-shared-symlink.ps1` checks that the agent loads `AGENTS-SHARED.md` when it is a symlink, following the include instruction in `AGENTS.md`.

**Requirements:**

- Git
- Rights to create symlinks (Windows: Developer Mode or an elevated shell)
