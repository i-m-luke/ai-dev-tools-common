# manage-github-issues

[`manage-github-issues`](../../skills/manage-github-issues/SKILL.md) lets an agent work with the
issues and pull requests of one GitHub repository — create, read, list, comment, label, assign, edit,
close, and link issues as sub-issues or blockers — through scripts that call GitHub CLI.

## Using it from a repo

The skill is hybrid: it runs only on `/manage-github-issues`, so a repo whose agents track work in
GitHub issues points at it from its `AGENTS.md`, naming the repository:

```markdown
## Issue tracker

Before creating, reading, commenting on, labelling, assigning or closing an issue or a pull request,
run `/manage-github-issues` with repo `<owner>/<name>`.
```

How a repo's own workflows map onto the operations — e.g. which labels mark triage states, or how
Matt Pocock's `/to-spec`, `/triage` and `/wayfinder` publish and claim tickets — stays in that
repo's `AGENTS.md`; the skill holds only what holds for any GitHub repository.

## Prerequisites

- PowerShell — `pwsh` 7+, or Windows PowerShell 5.1; the scripts run on both.
- [GitHub CLI](https://cli.github.com) (`gh`) on PATH, logged in to github.com with access to the
  repository (`gh auth login`).

The skill's initialization (`check-prerequisites.ps1`) checks both of `gh`'s conditions and that the
repository has issues enabled, and tells the user what to fix.

## Design

- **Repository as an argument.** Every script takes `-Repository`; nothing is inferred from git
  remotes, which may be missing (a clone without `origin`) or point at a mirror on another host.
- **Texts as files.** Markdown bodies and comments go in as `-BodyPath`/`-CommentPath` files, which
  keeps them clear of shell quoting; the agent writes them to
  `.artifacts/manage-github-issues/<yyyyMMdd-HHmmss>/`.
- **REST through `gh api`.** Every script except `get-issues.ps1` calls the REST API, which
  serves issues and pull requests alike from one number space (`/issues/<n>`), and is the only API
  with the pull request `author_association` and the sub-issues and dependencies endpoints.
  `get-issues.ps1` uses `gh issue list`, which returns the comments in the same call.
- **No `--jq`.** Windows PowerShell 5.1 breaks native arguments containing `"`, so the scripts shape
  JSON in PowerShell, never in jq expressions.
- **Feature detection.** `add-sub-issue.ps1`, `add-blocker.ps1` and `get-ready-sub-issues.ps1` read
  the issues they name first; an HTTP 404 from the sub-issues or dependencies endpoint after that
  means the feature is missing (exit code 21), not the issue.
- **Shared module.** `scripts/github-client.psm1` holds what every script needs — calling `gh`
  without stopping on its stderr, paging REST lists, emitting the result, ending with an expected
  failure. It is not a script to run, and `SKILL.md` does not list it.

## Tests

The [script tests](../verification/script-tests.md) in `tests/script-tests/manage-github-issues/`
never reach GitHub: `gh-stub/gh.ps1` stands in for GitHub CLI, first on the child process's PATH,
answers each call by the first matching rule the test set, and logs the call with its stdin so a test
can check the request. Each script's main case runs under both `pwsh` and `powershell`.

## Verifying changes

Run every script you touch against a real repository too: the stub checks the requests the scripts
make, not that GitHub accepts them. Read-only scripts can run against any accessible repository;
run the ones that write against a scratch repository you own, and delete what they created.

## Adding an operation

Add a `<verb>-<noun>.ps1` script that imports `github-client.psm1`, with comment-based help in the
outline of the [script contract](../../skills/skill-authoring/references/scripts.md), its Pester
tests and their `suite.test` line in `tests/script-tests.test.ts`, and a row in the operations table
of `SKILL.md`.
