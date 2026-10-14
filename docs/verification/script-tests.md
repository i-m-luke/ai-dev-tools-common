# Script tests

`./tools/script-tests.ps1` runs every [Pester](https://pester.dev) test in `script-tests/`; they
cover the scripts the skills ship (e.g. `skills/notify/scripts/notify.ps1`) and every skill's
frontmatter (see [guidelines](../guidelines/index.md)), and consume no tokens.

Tests are grouped by the skill they cover: `script-tests/<skill>/*.Tests.ps1`; the frontmatter check,
which covers all skills, lives in `script-tests/skill-frontmatter/`, and tests of the repo's own tools
live in `script-tests/tools/`.

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
