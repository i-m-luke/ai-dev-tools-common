# Script tests

`./tools/script-tests.ps1` runs every [Pester](https://pester.dev) test in `script-tests/`; they
cover the scripts the skills ship (e.g. `skills/notify/scripts/notify.ps1`) and consume no tokens.

Tests are grouped by the skill they cover: `script-tests/<skill>/*.Tests.ps1`.

Requirements: PowerShell 7+ (`pwsh`) and Pester 5+ (`Install-Module Pester -Scope CurrentUser -MinimumVersion 5.0 -Force -SkipPublisherCheck`).
