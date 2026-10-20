# Repository checks

`npm run repo-checks` runs every [Pester](https://pester.dev) test in `tests/repo-checks/` through
[Vitest](https://vitest.dev), one Vitest test per file; they enforce the
[guidelines](../guidelines/skills.md) every skill follows and consume no tokens.

The checks that cover all skills live in `tests/repo-checks/skill-frontmatter/` (frontmatter and
invocation, with the approved implicit skills in the root `implicit-skills.yaml`) and
`tests/repo-checks/skill-structure/` (folder layout, step numbering, script tests, mentions of assets
and references).

Each check has its own tests (`*.Fixtures.Tests.ps1`), which run first: a broken check cannot
validate the skills, so when one of them fails, the remaining tests are skipped. A new file needs its
line in `tests/repo-checks.test.ts`; a test there fails when the list and the files differ.

Requirements:

- Node.js 22+ and `npm install` in the repo root
- PowerShell 7+ (`pwsh`)
- Pester 5+ (`Install-Module Pester -Scope CurrentUser -MinimumVersion 5.0 -Force -SkipPublisherCheck`)
- powershell-yaml (`Install-Module powershell-yaml -Scope CurrentUser -Force`)

## CI

The `Repo checks` GitHub Actions workflow (`.github/workflows/repo-checks.yml`) runs the checks on
every push and pull request; a failing check fails the job.

No pre-commit hook runs them any more; a clone that enabled the former `.githooks/` hook resets it with
`git config --unset core.hooksPath`.
