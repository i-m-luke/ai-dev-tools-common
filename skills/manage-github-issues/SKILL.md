---
name: manage-github-issues
description: Use ONLY when the literal text "/manage-github-issues" appears in the request or instructions — never otherwise, whatever the task.
argument-hint: "The repository as owner/name, then what to do, e.g. owner/name — read issue 42"
---

Carry out the requested operations on the issues and pull requests of one GitHub repository — create, read, list, comment, label, assign, edit, close, and link issues as sub-issues or blockers — through the skill's scripts, which call GitHub CLI.

The repository, as `<owner>/<name>`, comes with the invocation, e.g. `Run /manage-github-issues with repo l-kratochvil/tools`; pass exactly that one to every script as `-Repository`. When the invocation names none, ask the user for it.

## Initialization

Run `pwsh -NoProfile -File <this skill's folder>/scripts/check-prerequisites.ps1 -Repository <owner/name>` once per repository in the conversation; use `powershell` in place of `pwsh` when pwsh is missing. Act on the script's exit code by this playbook:

- `0` — continue.
- `2` — GitHub CLI is missing; offer the user to install it from <https://cli.github.com>. Once installed, run this step again — at most once; when it still exits non-zero, show the user the script's stderr and stop.
- `3` — GitHub CLI is not logged in; ask the user to run `gh auth login`, which is interactive. Once they confirm, run this step again — at most once; when it still exits non-zero, show the user the script's stderr and stop.
- `4` — tell the user the repository is not accessible or has issues disabled, quoting stderr, and stop.
- `*` — show the user the script's stderr, or the error when it failed to start, and stop.

Done when the script exited 0 for the repository.

## Steps

### 1. Pick the scripts

Map each operation of the request to its script:

| Operation                                                                | Script                     |
| ------------------------------------------------------------------------ | -------------------------- |
| Create an issue                                                          | `new-issue.ps1`            |
| Read an issue or a pull request — a bare `#42` may be either             | `get-item.ps1`             |
| List issues, by state and labels                                         | `get-issues.ps1`           |
| List the open pull requests of external contributors                     | `get-external-prs.ps1`     |
| Comment on an issue or a pull request                                    | `add-comment.ps1`          |
| Add or remove labels                                                     | `set-labels.ps1`           |
| Assign a user; `@me` claims the item                                     | `add-assignee.ps1`         |
| Change a title or a body; to append, read the body with `get-item.ps1` first | `update-issue.ps1`     |
| Close an issue or a pull request, optionally with a comment              | `close-item.ps1`           |
| Put an issue under a parent issue as a sub-issue                         | `add-sub-issue.ps1`        |
| Mark an issue as blocked by another                                      | `add-blocker.ps1`          |
| List the sub-issues ready to work on — open, unassigned and unblocked    | `get-ready-sub-issues.ps1` |

When an operation matches no row, tell the user which one and stop. Done when every operation of the request has its script.

### 2. Write the texts

Write every Markdown text a script takes as a file — an issue body, a comment — to `.artifacts/manage-github-issues/<yyyyMMdd-HHmmss>/` in the workspace root, UTF-8, one folder per run of the skill; create the folder first. A file keeps the text clear of shell quoting. Done when every text the scripts need is in a file, or the operations need none.

### 3. Run the scripts

Run each script as `pwsh -NoProfile -File <this skill's folder>/scripts/<script> -Repository <owner/name> …`, with `powershell` in place of `pwsh` when pwsh is missing, one at a time in the order the operations depend on each other — e.g. create the issues before linking them. Act on each script's exit code by this playbook:

- `0` — take the result and run the next script.
- `3` — tell the user what GitHub could not do, quoting stderr, e.g. sub-issues not available, and stop.
- `*` — show the user the script's stderr, or the error when it failed to start, and stop.

Done when every script exited 0.

### 4. Report

Give the requester — the user, or the instructions that invoked the skill — what each operation produced: the read or listed content they asked for, and the number and URL of every item created or changed. Done when the requester has it.

## Scripts

Print a script's help with `pwsh -NoProfile -Command "Get-Help '<this skill's folder>/scripts/<script>' -Full"` and read it before you run the script for the first time. Read the script's source only when the help leaves out what you need, and then tell the user which part the help left out.

The exit code alone decides whether a script succeeded:

- On `0`, when the help says the script returns a result, take the compact JSON after `::result::` on the one stdout line that starts with it; every other stdout line is log. When that line is missing or appears more than once, tell the user the script broke its contract and stop.
- On any other exit code, ignore stdout; the error is on stderr.
