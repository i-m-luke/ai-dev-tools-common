# Script tests

`./tools/script-tests.ps1` runs every [Pester](https://pester.dev) test in `script-tests/`; they
cover the scripts the skills ship (e.g. `skills/notify/scripts/notify.ps1`) and the
[guidelines](../guidelines/skills.md) every skill follows, and consume no tokens.

Tests are grouped by the skill they cover: `script-tests/<skill>/*.Tests.ps1`. The checks that cover
all skills live in `script-tests/skill-frontmatter/` (frontmatter and invocation, with the approved
implicit skills in `implicit-skills.yaml`) and `script-tests/skill-structure/` (folder layout, step
numbering, script tests, mentions of assets and references); tests of the repo's own tools live in
`script-tests/tools/`.

Each check has its own tests (`*.Fixtures.Tests.ps1`), which run first: a broken check cannot
validate the skills, so when one of them fails, the remaining tests are skipped.

Requirements:

- PowerShell 7+ (`pwsh`)
- Pester 5+ (`Install-Module Pester -Scope CurrentUser -MinimumVersion 5.0 -Force -SkipPublisherCheck`)
- powershell-yaml (`Install-Module powershell-yaml -Scope CurrentUser -Force`)

## CI

The `Script tests` GitHub Actions workflow (`.github/workflows/script-tests.yml`) runs the suite on
every push and pull request (never waza evals, so it consumes no tokens); a failing test fails the job.

## Pre-commit hook

The versioned `.githooks/pre-commit` hook runs the script tests (never waza evals) and blocks the
commit when one fails. Enable it once per clone with `git config core.hooksPath .githooks`.
On failure it lists the failed tests first, then the full output; skip it once with VS Code's
"Commit (No Verify)" (enabled in `.vscode/settings.json`) or `git commit --no-verify`.
