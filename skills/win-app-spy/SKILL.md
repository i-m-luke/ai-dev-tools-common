---
name: win-app-spy
description: Use when a task requires UI inspection of a Windows app, whether to explore its UI structure, check element state, capture a screenshot or interact with it.
---

Inspect the UI of any Windows desktop app — its element tree and element states — interact with it and capture screenshots of it.

## Initialization

Run the initialization once per conversation.

### 1. Check prerequisites

Run `pwsh -NoProfile -File <this skill's folder>/scripts/check-prerequisites.ps1`; use `powershell` in place of `pwsh` when pwsh is missing. Act on the script's exit code by this playbook:

- `0` — continue.
- `20` — a prerequisite is missing; offer the user to install what stderr names. Once installed, run
  this step again — at most once; when it still exits non-zero, show the user the script's stderr
  and stop.
- `*` — show the user the script's stderr, or the error when it failed to start, and stop.

Done when the script exits `0`.

### 2. Create the working folder

Run `dotnet script <this skill's folder>/scripts/spy.csx -- --new-working-folder`; the first run compiles the script and takes longer. Act on the script's exit code by this playbook:

- `0` — tell the user the `workingFolder` path from the result: it holds this conversation's requests, session state and screenshots, and stays after the task for the user to review and delete.
- `*` — read `references/troubleshooting.md` and follow its section for the output; when none fits, show the user the script's stderr and stop.

Done when the user knows the working folder's path.

## Steps

### 1. Inspect and interact

Send each request by writing it as a JSON object into `req.json` in the working folder and running
`dotnet script <this skill's folder>/scripts/spy.csx -- --request-path <working folder>/req.json`.
Act on the script's exit code by this playbook:

- `0` — use the result's `data`; act on an item inside it that carries an `error` as on exit `20`.
- `20` — act on the error's `code`:
  - `APP_AMBIGUOUS` — resend with the `pid` of the app you mean; ask the user when the titles in the message don't tell.
  - `AMBIGUOUS_MATCH` — resend with the xpath of the candidate you mean, or narrow the xpath.
  - `APP_ALREADY_RUNNING` — ask the user to close that app, then `launch` again.
  - `*` — fix the request as the message says; when it names something only the user can do, tell the user.
- `*` — read `references/troubleshooting.md` and follow its section for the output; when none fits, show the user the script's stderr and stop.

Work the app through the commands:

- Start the app with `launch`, or `attach` to one already running — a user's app only when the user asked you to inspect it. Either makes the app the active one, which later requests target unless they send `app`; in `app`, prefer `pid` when you know it.
- Learn the app's structure with `dump-tree`, read elements with `get-state`, wait for asynchronous UI changes with `wait`, and capture what the app shows with `screenshot`, then open the PNG to look at it.
- Read `references/xpath.md` when you write a locator. A locator the user gave takes precedence over yours: send it, and use your own only when the user's fails. Send a fallback locator as a further item of the same `get-state` request.
- Read `references/troubleshooting.md` when the tree comes back empty or every locator answers `ELEMENT_NOT_FOUND`.
- Use `act` only when the task requires interacting with the app (see [Safety](#safety)).
- Read `references/flaui-basics.md` when no command does what the task needs; it shows how to write an ad hoc script.

Done when every question the task asks about the UI is answered and every interaction it needs is done.

### 2. Close the apps you launched

Send `close` for every app you launched — without `app` it closes the active app, with `app` another one. Act on the script's exit code by this playbook:

- `0` — continue with the next app.
- `20` with `TIMEOUT` — the app may be asking to save changes; send `close` again with `"force": true`.
- `*` — act as the playbook of step 1 does.

Apps you did not launch stay open; `close` refuses them with `NOT_LAUNCHED`. Done when every app you launched is closed.

## Scripts

Print a script's help with `dotnet script <this skill's folder>/scripts/spy.csx -- --help` (a command's with `-- --help <command>`, before you first send that command) or `pwsh -NoProfile -Command "Get-Help '<this skill's folder>/scripts/check-prerequisites.ps1' -Full"`, and read it before you run the script for the first time. Read the script's source only when the help leaves out what you need, and then tell the user which part the help left out.

The exit code alone decides whether a script succeeded:

- On `0`, when the help says the script returns a result, take the compact JSON after `::result::` on the one stdout line that starts with it; every other stdout line is log. When that line is missing or appears more than once, tell the user the script broke its contract and stop.
- On any other exit code, ignore stdout; the error is on stderr.

## Safety

- The skill is read-only by default: use `act` only when the task requires interacting with the app.
- Never click destructive controls (Delete, Uninstall, Send, …) unless the user explicitly asked.
- Never type into or change the user's own documents; in an app the user also uses, work in a new tab or window and undo your input before closing.

## Source changes

Address elements by xpath. Add an `AutomationId` to the app's source only as a last resort: when no xpath reaches the element reliably and the app's source code is at hand. Read `references/automation-id.md` when you add one, set it the way it shows for the app's UI framework, then rebuild and relaunch the app. These edits are temporary scaffolding:

- **Log** each edit in `changes.md` in the working folder before you make it — the file, the element, the id, and whether the file had uncommitted changes (`git status`) before your edit.
- **Revert** every logged edit when the task ends, touching only the logged files: restore a file that was clean before with `git restore <file>`; in a file that already had changes, or outside git, remove just your logged lines by hand. Done when each touched file is back to its pre-edit state.
- **Report** to the user which ids you removed, from which files.
- **Leave them uncommitted**: never stage or commit these edits; they live only in the working tree until the revert.
