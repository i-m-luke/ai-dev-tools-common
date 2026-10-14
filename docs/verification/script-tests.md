# Script tests

`./tools/script-tests.ps1` runs every [Pester](https://pester.dev) test in `script-tests/`; they
cover the scripts the skills ship (e.g. `skills/notify/scripts/notify.ps1`) and every skill's
frontmatter (see [guidelines](../guidelines/index.md)), and consume no tokens.

Tests are grouped by the skill they cover: `script-tests/<skill>/*.Tests.ps1`; the frontmatter check,
which covers all skills, lives in `script-tests/skill-frontmatter/`.

Requirements:

- PowerShell 7+ (`pwsh`)
- Pester 5+ (`Install-Module Pester -Scope CurrentUser -MinimumVersion 5.0 -Force -SkipPublisherCheck`)
- powershell-yaml (`Install-Module powershell-yaml -Scope CurrentUser -Force`)
