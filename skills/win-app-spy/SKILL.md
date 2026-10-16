---
name: win-app-spy
description: Use when a task requires UI inspection of a Windows app, whether to explore its UI structure, check element state, capture a screenshot or interact with it.
---

Inspect the UI of any Windows desktop app — its element tree, element states and screenshots — and
interact with it, without needing the app's source code.

## Steps

Steps 1 and 2 run once per conversation.

### 1. Check the environment

Run `pwsh -NoProfile -File <this skill's folder>/scripts/preflight.ps1`; use `powershell` in place
of `pwsh` when pwsh is missing. Act on its exit code by this playbook:

- `0` — continue; the script printed the versions it found.
- `1` — show the user the installation instructions the script printed to stderr and ask whether to
  run them; once the prerequisites are installed, run this step again.
- `*` — tell the user the script's stderr, or the error when the script failed to run, and end the
  skill.

### 2. Set up the working folder

The working folder `%TEMP%\win-app-spy\<yyyyMMdd-HHmmss>` (current local time) holds this
conversation's script copies, requests, session state and screenshots. Tell the user its path, then
create it and copy everything from `<this skill's folder>/scripts/` into it; run the scripts from
there, so the skill's own files stay untouched.

Keep the folder when the task ends: the user reviews the requests and screenshots there and deletes
it when they choose. It deliberately replaces the usual `.artifacts/` folder in the workspace,
because the skill works in any repository, or none.

### 3. Send a request

Write the request as a JSON object into `req.json` in the working folder; its `command` selects
what the script does. From the working folder, run `dotnet script win-app-spy.csx -- req.json` —
the first run in a new working folder compiles the script and takes longer. Act on the result by
this playbook:

- `0` — use the JSON it printed (see [Response](#response)).
- `1` with JSON — an `error` in the JSON says what failed (see [Error codes](#error-codes)); fix the
  request or follow the error's message.
- `*` without JSON — the environment failed (compilation, NuGet restore, a crash); follow `references/troubleshooting.md`, else show the user the output and end the skill.

Start the app to inspect with `launch`; it waits up to `timeout` ms (default 10000) for the app's
window and makes the app the active one, so later requests may leave out `app`:

```json
{ "command": "launch", "exe": "notepad.exe", "args": "", "timeout": 10000 }
```

Send `"app": { "pid": 1234 }` to target an app other than the active one.

To inspect an app that is already running, `attach` to it; it makes the app the active one but
never counts it as launched, so `close` leaves it open. Pick the app by exactly one of `pid`,
`process` (the exe name) or `title` (part of a window title, any case) — `app` takes these forms
in every request:

```json
{ "command": "attach", "app": { "process": "notepad" } }
```

Prefer `pid` when you know it: on `APP_AMBIGUOUS` resend with the pid of the app you mean, asking
the user when the message's titles don't tell. Attach to a user's app only when the user asked you
to inspect it.

Requests use UIA3 unless they send `"uia": "UIA2"`; `launch` keeps its mode for the active app.
When the element tree comes back empty or a request errors on an app, retry it with the other mode.

Read elements with `get-state`: send XPath `locators` (written as `references/xpath.md` describes)
and the `states` keys you need; without `states` it only checks that each locator finds exactly one
element:

```json
{ "command": "get-state", "locators": ["//MenuItem[@AutomationId='File']"], "states": ["enabled"] }
```

Each locator gets its own result item, so send a fallback locator as a further item in the same
list rather than in a second request. A locator the user gave takes precedence over yours: send it,
and use your own locator's result only when the user's fails.

To collect every match at once, send a locator object `{ "xpath": "...", "all": true }`; its item
returns `matches`, each with a concrete xpath and the requested state.

To learn an app's structure, `dump-tree` lists its element tree with a ready-to-use xpath per node;
narrow it with `root` (an xpath) and `depth`, see `references/output-format.md`:

```json
{ "command": "dump-tree", "depth": 2, "states": ["name"] }
```

Capture what the app shows with `screenshot`: it saves a PNG of the app's front window, or of the
one element an `xpath` matches, into the working folder and returns its `path`; open the image to
look at it:

```json
{ "command": "screenshot", "xpath": "//MenuItem[@AutomationId='File']" }
```

Interact with `act` only when the task requires it (see [Safety](#safety)): its `locator` must
match exactly one element, else nothing happens. `action` is one of `click`, `doubleClick`,
`rightClick`, `focus`, `type` (+ `text`), `setValue` (+ `value`), `invoke`, `toggle`, `select`,
`expand`, `collapse`, `key` (+ `keys`, e.g. `Ctrl+A`, `Escape`); send `states` to check the effect:

```json
{ "command": "act", "locator": "//MenuItem[@AutomationId='View']", "action": "expand", "states": ["expanded"] }
```

When the UI changes asynchronously (a dialog opens, a button enables), `wait` polls a `locator`
until its `condition` holds — `exists` (default), `gone`, `enabled` or `visible` — every `poll` ms
(default 250) for up to `timeout` ms (default 10000), else answers `TIMEOUT`:

```json
{ "command": "wait", "locator": "//MenuItem[@AutomationId='File']", "condition": "enabled", "timeout": 5000 }
```

### 4. Close the apps you launched

When the task ends, close every app you launched: `{ "command": "close" }` closes the active app,
`"app": { "pid": 1234 }` another one. `close` closes the app's windows and waits up to `timeout` ms
for it to exit; on `TIMEOUT` (e.g. a save prompt) send it again with `"force": true` to kill the
app. Apps you did not launch stay open — `close` refuses them with `NOT_LAUNCHED`.

## Response

Every run prints one JSON object: `command`, then `data` on success or `error` (`code`,
`message`) on failure; empty fields are left out. An `error` may also sit on an item inside `data`.
The exit code is 0 when no `error` appears anywhere, otherwise 1. The response of each command is
in `references/output-format.md`.

## Error codes

| Code                  | Meaning                                                                                                                                            |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `INVALID_REQUEST`     | The request file is missing, not a JSON object, or a field is missing or of the wrong type; on an item, its xpath is outside the supported subset. |
| `UNKNOWN_COMMAND`     | No such command; the message lists the known ones.                                                                                                 |
| `APP_NOT_FOUND`       | The exe cannot be started, no process has the pid, no app with a window matches `app`, or there is no active app.                                  |
| `APP_AMBIGUOUS`       | Several apps match `app`'s `process` or `title`; the message lists their pids and titles.                                                          |
| `APP_ALREADY_RUNNING` | `launch` saw the window open in an instance that was already running and not launched by you; ask the user to close that app, then launch again.   |
| `NOT_LAUNCHED`        | `close` targets an app not launched in this working folder.                                                                                        |
| `CLOSE_FAILED`        | The app has no window to close; send `"force": true`.                                                                                              |
| `ELEMENT_NOT_FOUND`   | A locator matched no element.                                                                                                                      |
| `AMBIGUOUS_MATCH`     | A locator matched several elements; `count` gives how many, `candidates` the concrete xpaths of the first 5 — send the intended one.               |
| `ACTION_FAILED`       | `act` could not perform the action, e.g. the element lacks its pattern; the message suggests an alternative.                                       |
| `TIMEOUT`             | `launch` saw no window in time (it stopped the process it started), `close` saw the app still running, or `wait`'s condition did not hold in time. |
| `UNEXPECTED`          | Any other failure; the message holds the details.                                                                                                  |

## Safety

- The skill is read-only by default: use `act` only when the task requires interacting with the app.
- Never click destructive controls (Delete, Uninstall, Send, …) unless the user explicitly asked.
- Never type into or change the user's own documents; in an app the user also uses, work in a new
  tab or window and undo your input before closing.

## Source changes

Address elements by xpath. Add an `AutomationId` to the app's source only as a last resort: when no
xpath reaches the element reliably and the app's source code is at hand. Set it the way
`references/automation-id.md` shows for the app's UI framework, then rebuild and relaunch the app.
These edits are temporary scaffolding:

- **Log** each edit in `changes.md` in the working folder before you make it — the file, the
  element, the id, and whether the file had uncommitted changes (`git status`) before your edit.
- **Revert** every logged edit when the task ends, touching only the logged files: restore a file
  that was clean before with `git restore <file>`; in a file that already had changes, or outside
  git, remove just your logged lines by hand. Done when each touched file is back to its pre-edit
  state.
- **Report** to the user which ids you removed, from which files.
- **Leave them uncommitted**: never stage or commit these edits; they live only in the working tree
  until the revert.

## References

- `references/automation-id.md` — how to set an `AutomationId` in each .NET UI framework; read it
  when [Source changes](#source-changes) calls for one.
- `references/flaui-basics.md` — FlaUI basics and the shared core's API; read it when no command does what the task needs and you write an ad hoc script.
- `references/output-format.md` — the response envelope, the error object, the exit code and the
  `data` of each command; read it when you need the exact shape of a response.
- `references/troubleshooting.md` — recovery from environment problems (no JSON, NuGet, missing
  dotnet-script, an empty tree, UIA2 vs UIA3, admin apps); read it when a run fails without a
  usable `error` or the tree comes back empty.
- `references/xpath.md` — the XPath subset of locators, the root over all windows, dialogs and how
  long an xpath stays valid; read it before writing a locator.
