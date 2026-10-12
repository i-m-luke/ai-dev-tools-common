---
name: notify
description: Use when asked to send the user a remote message. Tells you how to reach them when a turn ends with a question, plan approval, blocker, or finished work.
---

Roles: Robot

Send the user a Telegram message, so they know the session is waiting for them. Do the user's task
first; run the steps below right before ending the turn. Once asked, do so at the end of every turn
that waits for the user, until the user explicitly says they are back (e.g. "I'm back") or asks you
to stop notifying; ordinary task replies do not count as being back.

1. Write the message, one or two lines, in this format:
   `<repository or working folder name>: <what you need from the user or what you finished>`
2. Run `pwsh -NoProfile -File <this skill's folder>/scripts/notify.ps1 -Msg "<message>"`; use
   `powershell` in place of `pwsh` when pwsh is missing. If neither is available, tell the user the
   notification could not be sent because PowerShell is not installed, and end the turn normally.
3. Act on the script's exit code by the table below, then end the turn as you would have.

# Exit codes

| Code | Meaning                                                                          | Action                                                                                      |
| ---- | -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| 0    | Message sent.                                                                    | None.                                                                                       |
| 1    | Config file 'agents.secrets.yaml' not found.                                     | Tell the user the searched paths from the script's output and the file's structure (below). |
| 2    | Config file invalid: unreadable, no `notify` section, or empty `token`/`chatId`. | Tell the user the problem from the script's output.                                         |
| 3    | Telegram API or network error.                                                   | Tell the user the error from the script's output; send no retry.                            |
| \*   | Any other exit code, or the script failed to run.                                | Tell the user the raw output or error; send no retry.                                       |

# Config file structure

```yaml
notify:
  token: "<bot token>"
  chatId: "<chat ID>"
```

- `token` is the bot's token
- `chatId` the user's chat with the bot.
