---
name: notify
description: Required for every task that edits files, runs commands, or asks the user for a decision (question, plan approval, blocker); load it first, as it tells you how to notify the user via Telegram when your turn ends. Skip only purely conversational replies.
---

Roles: Robot

Send the user a Telegram message, so they know the session is waiting for them. Do the user's task
first; run the steps below right before ending the turn.

1. Write the message: one or two lines starting with the repository (or working folder) name, then
   what you need from the user or what you finished, e.g.
   `ai-dev-tools-common: plan ready, waiting for approval.`
2. Run `pwsh -NoProfile -File <this skill's folder>/scripts/notify.ps1 -Msg "<message>"`; use
   `powershell` in place of `pwsh` when pwsh is missing.
3. Act on the script's exit code by the table below, then end the turn as you would have.

## Exit codes

| Code | Meaning | Action |
|---|---|---|
| 0 | Message sent. | None. |
| 1 | Config file 'agents.secrets.yaml' not found. | Tell the user the searched paths from the script's output and the file's structure (below). |
| 2 | Config file invalid: unreadable, no `notify` section, or empty `token`/`chatId`. | Tell the user the problem from the script's output. |
| 3 | Telegram API or network error. | Tell the user the error from the script's output; send no retry. |

Config file structure (`token` is the bot's token, `chatId` the user's chat with the bot):

```yaml
notify:
  token: "<bot token>"
  chatId: "<chat ID>"
```
