# Script tests

`./tools/script-tests.ps1` runs every [Pester](https://pester.dev) test in `script-tests/`; they
cover the scripts the skills ship (e.g. `skills/notify/scripts/notify.ps1`) and consume no tokens.

Tests are grouped by the skill they cover: `script-tests/<skill>/*.Tests.ps1`; tests of the repo's
own tools live in `script-tests/tools/`.

Requirements: PowerShell 7+ (`pwsh`) and Pester 5+ (`Install-Module Pester -Scope CurrentUser -MinimumVersion 5.0 -Force -SkipPublisherCheck`).

## Pre-commit hook

The versioned `.githooks/pre-commit` hook runs the script tests (never waza evals) and blocks the
commit when one fails. Enable it once per clone with `git config core.hooksPath .githooks`.
