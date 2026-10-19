---
name: notify
description: Use ONLY when the literal text "/notify" appears in the request or instructions — never otherwise, whatever the task.
argument-hint: "What to report and when, e.g. when the task is done or you are blocked"
---

Roles: Robot — for this skill's steps only. If the role definition is not available use this one instead:

> carry out the given instructions (user's, skill's, doc's) mechanically, step by step, exactly as written. Where an instruction is missing, ambiguous, or cannot be carried out — even where another instruction lets you use your own judgement — stop before doing it, create nothing from it or from the instructions after it, and ask the user rather than improvise or fill in a default. Applies only to the instructions in the file (message or document) where it was assigned, also when assigned in plain words ("run the instructions below as a robot"); anything outside it keeps your own judgement.

Send the user a Telegram message each time their instructions call for one — e.g. progress, finished
work, a question, or a blocker. A standing request holds until the user says they are back or asks
you to stop notifying; ordinary task replies do not count as being back.

## Steps

### 1. Run the script

Run `pwsh -NoProfile -File <this skill's folder>/scripts/notify.ps1 -Message "<what you report>" -WorkingFolderName "<repository or working folder name>"`;
use `powershell` in place of `pwsh` when pwsh is missing. If neither is available, tell the user
the notification could not be sent because PowerShell is not installed, and end the skill.

### 2. Act on the exit code

Act on the script's exit code by this playbook:

- `0` — none; the message was sent.
- `*` — tell the user, in the conversation's language, the script's stderr, or the error when the
  script failed to run; leave the retry to the user.
