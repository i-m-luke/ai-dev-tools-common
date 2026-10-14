---
name: notify
description: Use when asked to message or notify the user remotely.
---

Roles: Robot — for this skill's steps only. Where no definition of Robot is available, follow the
steps below exactly as written; where one is missing, ambiguous, or cannot be carried out, stop and
ask the user.

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
