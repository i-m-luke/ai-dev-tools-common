# notify

[`notify`](../../skills/notify/SKILL.md) sends the user a Telegram message through a bot. It reads the bot token and chat ID from
`agents.secrets.yaml`, looked up in the current git repository's root, then in `~/.agents/`. Keep
the file git-ignored in any repo it lives in.

```yaml
notify:
  token: "<bot token>"
  chatId: "<chat ID>"
```
