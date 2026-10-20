# Script tests

`npm run script-tests` runs every [Pester](https://pester.dev) test file in `tests/script-tests/`
through [Vitest](https://vitest.dev), one Vitest test per file; they cover the scripts the skills
ship (e.g. `skills/notify/scripts/notify.ps1`) and consume no tokens.

- Run selected files: `npm run script-tests '--' -t notify` (a regex on the file's path, e.g.
  `win-app-spy/wait`; quote `--` in PowerShell). A filter matching no file fails the run.
- A failed file lists its failed Pester tests; Pester's own output streams above the summary.

Tests are grouped by the skill they cover: `tests/script-tests/<skill>/*.Tests.ps1`; the
[repository checks](repository-checks.md) verify that every skill script has them. A new file needs
its `suite.test('<skill>/<file>')` line in `tests/script-tests.test.ts`, so the VS Code Test Explorer
lists it before a run; a test there fails when the list and the files differ.

CI does not run them, since they drive real apps and services; run them
yourself whenever you change a skill's script.

Requirements:

- Node.js 22+ and `npm install` in the repo root
- PowerShell 7+ (`pwsh`)
- Pester 5+ (`Install-Module Pester -Scope CurrentUser -MinimumVersion 5.0 -Force -SkipPublisherCheck`)
