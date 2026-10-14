# Evals

- Run all evals: `./tools/evals.ps1`
- Run selected evals: `./tools/evals.ps1 -Name document-app, notify`

## Requirements

- PowerShell 7+ (`pwsh`)
- Copilot CLI (`copilot`) on PATH, logged in, and allowed by your Copilot policy (https://github.com/settings/copilot)
- [waza](https://github.com/microsoft/waza) for the skill evals, on PATH or in its default install folder (Windows: `irm https://raw.githubusercontent.com/microsoft/waza/main/install.ps1 | iex`)
- `evals.config.json` in the repo root (see below)

## Configuration

`evals.config.json` (git-ignored) must exist; it may be empty. Its optional `githubUser` picks the
GitHub account whose Copilot the evals use, so the right seat is used even when you have several
accounts or `GH_TOKEN` is set for another one:

```json
{ "githubUser": "your-github-login" }
```

Evals read it through `evals/utils/read-config.ps1`, which returns the file's values and stops the
eval when the file is missing or not valid JSON. With `githubUser` set, an eval takes the account's
token from GitHub CLI (`gh`, the account must be logged in via `gh auth login`) and hands it to
Copilot CLI (via `COPILOT_GITHUB_TOKEN`, for the eval's process only; see
`evals/utils/use-copilot-account.ps1`); without it, Copilot CLI picks its credentials as usual. A
`githubUser` not logged in to `gh` stops the eval too.

## Skill evals

Each skill has a [waza](https://github.com/microsoft/waza) eval in `evals/<skill>/`: `eval.yaml`,
behaviour tasks in `tasks/` run against the code in `fixtures/`, and, for skills the model invokes
on its own, `trigger_tests.yaml` with prompts that must and must not trigger the skill. Graders
check the skill invocations, the files the agent left, and its replies (LLM judge).

- Skills the model invokes on its own run with their body hidden, so the agent has to pick the
  skill itself.
- Skills only the user invokes (`disable-model-invocation`) run with their body injected: the agent
  receives a slash command as plain text, so injection stands in for the user typing it.
- External skills a skill relies on are replaced by stubs in `evals/_stub-skills/`, so the result
  doesn't depend on what is installed.

A full run consumes a lot of tokens; use `-Name` to run only the evals you changed.
