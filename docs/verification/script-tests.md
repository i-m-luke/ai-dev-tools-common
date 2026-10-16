# Script tests

`./tools/script-tests.ps1` runs every [Pester](https://pester.dev) test in `script-tests/`; they
cover the scripts the skills ship (e.g. `skills/notify/scripts/notify.ps1`) and consume no tokens.

Tests are grouped by the skill they cover: `script-tests/<skill>/*.Tests.ps1`; the
[repository checks](repository-checks.md) verify that every skill script has them.

Neither the pre-commit hook nor CI runs them, since they drive real apps and services; run them
yourself whenever you change a skill's script.

Requirements:

- PowerShell 7+ (`pwsh`)
- Pester 5+ (`Install-Module Pester -Scope CurrentUser -MinimumVersion 5.0 -Force -SkipPublisherCheck`)
