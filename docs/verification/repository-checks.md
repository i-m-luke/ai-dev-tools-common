# Repository checks

`./tools/repo-checks.ps1` runs every [Pester](https://pester.dev) test in `tools/repo-checks/`; they
enforce the [guidelines](../guidelines/skills.md) every skill follows and test the repo's own tools,
and consume no tokens.

The checks that cover all skills live in `tools/repo-checks/skill-frontmatter/` (frontmatter and
invocation, with the approved implicit skills in the root `implicit-skills.yaml`) and
`tools/repo-checks/skill-structure/` (folder layout, step numbering, script tests, mentions of assets
and references); tests of the repo's tools live directly in `tools/repo-checks/`.

Each check has its own tests (`*.Fixtures.Tests.ps1`), which run first: a broken check cannot
validate the skills, so when one of them fails, the remaining tests are skipped.

Requirements:

- PowerShell 7+ (`pwsh`)
- Pester 5+ (`Install-Module Pester -Scope CurrentUser -MinimumVersion 5.0 -Force -SkipPublisherCheck`)
- powershell-yaml (`Install-Module powershell-yaml -Scope CurrentUser -Force`)

## CI

The `Repo checks` GitHub Actions workflow (`.github/workflows/repo-checks.yml`) runs the checks on
every push and pull request; a failing check fails the job.

## Pre-commit hook

The versioned `.githooks/pre-commit` hook runs the repo checks and blocks the commit when one fails.
It NEVER runs the [script tests](script-tests.md) or waza evals. Enable it once per clone with
`git config core.hooksPath .githooks`.
On failure it lists the failed checks first, then the full output; skip it once with VS Code's
"Commit (No Verify)" (enabled in `.vscode/settings.json`) or `git commit --no-verify`.
