# exec-synt-workflow

[`exec-synt-workflow`](../../skills/exec-synt-workflow/SKILL.md) makes an agent follow a precise workflow — branching, and later loops and reusable tasks — exactly as written, instead of improvising from prose.

Put the workflow in a code block tagged `workflow`, then order the agent to execute it, or place the block in the instructions of another skill and the agent runs it implicitly. Ordinary code or pseudocode in a conversation does not trigger the skill.

````markdown
```workflow
if (The visitor is older than 18):
    Say "Welcome in"
else:
    Say "Come back when you are older"
```
````
