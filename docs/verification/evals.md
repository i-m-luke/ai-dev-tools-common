# Evals

- Run all evals: `./tools/evals.ps1`
- Run selected evals: `./tools/evals.ps1 -Name document-app, notify` — a name matching no eval is
  listed and the run exits 1 before any eval starts, so a typo never passes as success.
- Pick the model the skill evals run on: `./tools/evals.ps1 -Model claude-sonnet-5` (default
  `claude-sonnet-5.5`; overrides the `model` in each `eval.yaml`).
- Run the evals of [in-progress](../in-progress.md) content instead: `./tools/evals.ps1 -InProgress`
  (combinable with `-Name`); they live in `evals/in-progress/`, never run without the switch.
- Each run gets its own folder `.artifacts/evals-reports/<timestamp>/` (git-ignored) with everything
  the run produced:
  - `report.md` — the model, scope, duration, per-eval PASS/FAIL and the token usage table below. No
    report when the run stops early (unknown eval name, no evals).
  - `<eval>/` — the eval's output, so a failure can be investigated without rerunning: `console.txt`
    (what the eval printed) and, for waza evals, `results.json` (waza's results) and `transcripts/`
    (each task's agent transcript).
- After the run, a token usage table lists each waza eval's input, output, cache read and cache
  write tokens, estimated AI credits and premium requests, with a total row. It comes from the
  `usage` in waza's `results.json`; waza's own
  `USAGE SUMMARY` stays in the output. Script evals use no tokens and are left out.
  - *Est. credits* is computed from the tokens and the run's model price in
    `tools/model-prices.json` (USD per 1M tokens from GitHub's
    [models and pricing](https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing);
    1 credit = $0.01); waza's input tokens include the cache ones, so only the remainder is priced
    as input. It is an estimate: the real bill is on github.com. A model missing from the
    price file leaves the cell blank and out of the total; add its prices to use it.
  - *Premium requests* is a legacy unit: GitHub replaced it with AI credits on 2026-06-01. waza
    still reports it, so it stays for comparison only.

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

Evals read it through `tools/read-config.ps1`, which returns the file's values and stops the
eval when the file is missing or not valid JSON. With `githubUser` set, an eval takes the account's
token from GitHub CLI (`gh`, the account must be logged in via `gh auth login`) and hands it to
Copilot CLI (via `COPILOT_GITHUB_TOKEN`, for the eval's process only; see
`tools/use-copilot-account.ps1`); without it, Copilot CLI picks its credentials as usual. A
`githubUser` not logged in to `gh` stops the eval too.

## Skill evals

Each skill has a [waza](https://github.com/microsoft/waza) eval in `evals/<skill>/`: `eval.yaml`,
behaviour tasks in `tasks/` run against the code in `fixtures/`, and, for skills the model invokes
on its own, `trigger_tests.yaml` with prompts that must and must not trigger the skill — they run
against `fixtures/` too, so a prompt naming an existing file needs that file there. Graders
check the skill invocations, the files the agent left, and its replies (LLM judge).

- Skills the model invokes on its own run with their body hidden, so the agent has to pick the
  skill itself.
- Skills only the user invokes (`disable-model-invocation`) run with their body injected: the agent
  receives a slash command as plain text, so injection stands in for the user typing it.
- External skills a skill relies on are replaced by stubs in `evals/_stub-skills/`, so the result
  doesn't depend on what is installed.

A full run consumes a lot of tokens; use `-Name` to run only the evals you changed.

## Shared-instructions evals

Evals of the shared instructions (`AGENTS-SHARED.md` and `agents-shared/`) have no skill. Their
fixtures hold a strict `AGENTS.md` ("Always read AGENTS-SHARED.md in full, whatever the cost."), and
before the run `tools/evals.ps1` copies the real shared instructions into every fixture folder that
contains an `AGENTS.md`, so the eval tests the current text, not a stale copy. The copies are
git-ignored and removed afterwards, also when the run fails. They are copies, not symlinks: the repo
sets `core.symlinks=false` and waza copies fixtures into a temp workspace.

- `roles` — the agent prints `ACTIVATED ROLES: x, y, z` within the first 3 lines of its reply when
  one or several roles are assigned (listed in assigned order) and again when the set of roles
  changes in a later turn, and prints no such line when no role is assigned. Deterministic regex
  graders on the reply. Its Robot tasks use a Czech prompt ("Proveď instrukce níže jako robot…"):
  complete but unusual instructions are executed literally (file graders), an ambiguous instruction
  makes the agent ask and create nothing (file grader and LLM judge), and instructions in a fixture
  file run as Robot while an instruction outside it keeps the agent's own judgement (LLM judge).
- `agents-shared` — tests the shared instructions file itself: `Roles: Robot` makes the agent read
  `agents-shared/roles.md`, and the unfamiliar glossary term **playbook** makes it read
  `agents-shared/glossary.md` and write a list of outcome → action pairs (LLM judge, so reading the
  glossary has an effect). The reads are checked with a `tool_constraint` grader on the agent's
  `view` calls.
