# Tool skills

A tool skill gives the agent a set of commands — helpers it runs whenever a task needs one, in any order. Each command holds its own steps; the rules of `references/workflow-skills.md` for steps, completion conditions, playbooks, loops and reference hold here, with a command's chapter in place of `## Steps`.

## Shape

- **Overview** — open the body with one sentence stating what the tool is for, then list every command as `` `<command>` — <what it does and when to run it> ``. The agent picks a command by this list.
- **Initialization** — optionally, put what must hold before any command runs under an `## Initialization` chapter right after the overview, shaped as in a workflow skill. The agent runs it once per conversation, before the first command.
- **Commands** — give each command a chapter of its own, `## <command>`, in the order of the overview. Open it with one sentence on what the command does, then its steps as `### N. <action>`, numbered from 1 within the chapter; a single step may stay a paragraph. Refer to them as "step N of `<command>`".
- **Shared reference** — reference used by several commands gets a chapter after the last command.

## Skeleton

```markdown
<One sentence stating what the tool is for.>

- `<command-a>` — <what it does; when to run it>.
- `<command-b>` — <what it does; when to run it>.

## Initialization

Run the initialization once per conversation, before the first command.

### 1. <Action>

Run `<exact command>`. Act on the script's exit code by this playbook:

- `0` — continue.
- `*` — show the user the script's stderr and stop.

Done when <condition>.

## <command-a>

<One sentence on what the command does.>

### 1. <Action>

Run `<exact command>`. Act on the script's exit code by this playbook:

- `0` — <action>.
- `*` — show the user the script's stderr and stop.

Done when <condition>.

### 2. <Action>

<What the agent does.> Done when <condition>.

## <command-b>

<One sentence on what the command does.> Run `<exact command>`. Act on the script's exit code by this playbook:

- `0` — <action>.
- `*` — show the user the script's stderr and stop.

Done when <condition>.

## <Reference shared by several commands>
```
