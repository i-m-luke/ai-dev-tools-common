# Scripts

A script is a stateless function: its behaviour depends only on its input, and it keeps no state of its own between runs. It runs without interaction: it reads no input while it runs, and asks the agent only through its result (see [Dialog with the agent](#dialog-with-the-agent)).

This document describes the contract every script of a skill follows, in any language, so the agent runs a script from its help alone and acts on its outcome without guessing.

## Language

All scripts of a skill share one language, so the skill needs one runtime, except as [Prerequisites](#prerequisites) allows. Propose the language by the runtime the skill's users already have or the one its domain needs, PowerShell when nothing decides, and let the user confirm it before you write a script.

`references/powershell-scripts.md` works the contract out in PowerShell. For another language, derive the equivalent of each of its parts — invocation, help, emitting the result, tests — from the rules below.

## Name

Start a script's name with an imperative verb and add a noun when the verb alone leaves its object unclear: `<verb>[-<noun>].<ext>`, kebab-case. Helper files the scripts load, never run by the agent, are named by their content.

## Input

A script takes its input only as named parameters. Structured or multi-line input — JSON, a list, free text — comes in a file: name its parameter `<Noun>Path`, e.g. `-IssuesPath`, and describe the file's content under the help's Input. The agent writes that file to the `.temp/` folder that `assets/instruction-blocks/artifacts.md` describes; the script only reads it, so it can run again on the same input.

## Output

- **Result** — exactly one stdout line, `::result::` followed by compact JSON, e.g.
  `::result::{"path":"out/issues.csv","count":12}`, on exit code `0` or `3` and up. A script that has nothing to return prints no `::result::` line.
- **Log** — every other stdout line, whoever writes it: the script, a library or a child process.
- **Errors** — on stderr.

## Exit codes

The code's range alone tells the agent where the outcome is: the result on stdout, or the error on stderr.

| Code         | Meaning                                                                                                                                                                        |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `0`          | Success: the script did what it is for; the result, when the script returns one, is on stdout.                                                                                 |
| `1`          | Unexpected failure: an unhandled error. Runtimes exit with 1 on one, so 1 never means more.                                                                                    |
| `2`          | Expected failure; stderr says which.                                                                                                                                           |
| `3` and up   | Other expected outcomes, each documented in the help with its result on stdout — e.g. a [dialog with the agent](#dialog-with-the-agent), or an end short of the script's goal. |
| undocumented | Unexpected failure, like `1`.                                                                                                                                                  |

`0` is the outcome after which the skill goes on as usual; an outcome that changes the skill's course takes its own code from `3` up. An expected failure the agent must act on differently from the other failures is such an outcome too.

## Dialog with the agent

A script that needs a decision it cannot make itself — the user's answer, or the agent's judgement — stops with a code from `3` up and returns the question in its result, together with the exact command that continues the run for each answer. It keeps its progress in the run folder (see `assets/instruction-blocks/artifacts.md`) and takes that folder's path as a parameter, so the continuing command resumes where the run stopped. The skill bounds the dialog like any loop.

## Help

Document each script inside it, through the language's native help mechanism, in this outline:

1. **Purpose** — what the script does.
2. **Input** — each parameter, or that the script takes none.
3. **Result** — the shape of the result JSON for each exit code that returns one, or that the script returns none.
4. **Exit codes** — `0`, `2` when the script has expected failures, and each outcome from `3` up.
5. **Stderr** — what the script writes there.

The skill names the command that prints the help; the help is the only documentation of what the script returns and which errors it reports.

## Running scripts

A skill with scripts gives the agent the rules for running them through the instruction blocks: `assets/instruction-blocks/scripts.md`, with `{{help-command}}` filled in by the command that prints a script's help, and `assets/instruction-blocks/artifacts.md` when a script takes a `<Noun>Path` parameter.

Act on every script run by a playbook keyed by exit code: `0`, then a row for each documented code from `2` up, then `*` — show the user the script's stderr, or the error when it failed to start, and stop. `*` covers `1` and every undocumented code.

## Prerequisites

When the scripts need prerequisites beyond their runtime — modules, tools — the skill's first step runs `check-prerequisites.<ext>`, so the agent learns up front whether the skill can work. The script checks every such prerequisite and never its own runtime: a missing runtime shows up as the script failing to start, which `*` covers. When the runtime itself is a prerequisite — a tool such as dotnet-script — write `check-prerequisites` in a language the users already have, PowerShell by default, and let it check the runtime too; it is the only script of the skill that may differ in language.

```markdown
### 1. Check prerequisites

Run `<command>`. Act on the script's exit code by this playbook:

- `0` — continue.
- `2` — a prerequisite is missing; offer the user to install what stderr names. Once installed, run this step again — at most once; when it still exits non-zero, show the user the script's stderr and stop.
- `*` — show the user the script's stderr, or the error when it failed to start, and stop.
```
