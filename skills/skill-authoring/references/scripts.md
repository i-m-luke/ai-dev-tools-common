# Scripts

A script is a stateless function: its behaviour depends only on its input, and it keeps no state of its own between runs. It runs without interaction.

This document describes the contract every script of a skill follows, in any language, so the agent runs a script from its help alone and acts on its outcome without guessing.

## Language

All scripts of a skill share one language, so the skill needs one runtime. Propose the language by the runtime the skill's users already have or the one its domain needs, PowerShell when nothing decides, and let the user confirm it before you write a script.

`references/powershell-scripts.md` works the contract out in PowerShell. For another language, derive the equivalent of each of its parts — invocation, help, reading stdin, emitting the result, tests — from the rules below.

## Name

Name a script `<verb>-<noun>.<ext>`, kebab-case, starting with an imperative verb, e.g.
`export-issues.ps1` or `check-prerequisites.py`.

## Input

- Up to five inputs: scalar named parameters.
- More inputs, or a value that is not a scalar: the whole input as one JSON object on stdin, with no parameters beside it.

A call with many parameters is hard to read, and every value on a command line is a quoting trap; one JSON object keeps the input readable and in one place.

## Output

- **Result** — exactly one stdout line, `::result::` followed by compact JSON, e.g.
  `::result::{"path":"out/issues.csv","count":12}`. A script that has nothing to return prints no `::result::` line.
- **Log** — every other stdout line, whoever writes it: the script, a library or a child process.
- **Errors** — on stderr.

## Exit codes

| Code         | Meaning                                                                                     |
| ------------ | ------------------------------------------------------------------------------------------- |
| `0`          | Success; the result, when the script returns one, is on stdout.                             |
| `1`          | Unexpected failure: an unhandled error. Runtimes exit with 1 on one, so 1 never means more. |
| `2` and up   | Expected failures, each documented in the help with its meaning.                            |
| undocumented | Unexpected failure, like `1`.                                                               |

## Help

Document each script inside it, through the language's native help mechanism, in this outline:

1. **Purpose** — what the script does.
2. **Input** — each parameter, the shape of the JSON object on stdin, or that the script takes none.
3. **Result** — the shape of the result JSON, or that the script returns none.
4. **Exit codes** — `0` and each expected failure from `2` up.
5. **Stderr** — what the script writes there.

The skill names the command that prints the help; the help is the only documentation of what the script returns and which errors it reports.

## Running scripts

A skill with scripts gives the agent these rules in a chapter beside `## Steps`, filled in:

```markdown
## Scripts

Print a script's help with `<help command>` and read it before you run the script for the first time. Read the script's source only when the help leaves out what you need, and then tell the user which part the help left out.

The exit code alone decides whether a script succeeded:

- On `0`, when the help says the script returns a result, take the compact JSON after `::result::` on the one stdout line that starts with it; every other stdout line is log. When that line is missing or appears more than once, tell the user the script broke its contract and stop.
- On any other exit code, ignore stdout; the error is on stderr.
```

Act on every script run by a playbook keyed by exit code: `0`, then a row for each documented code from `2` up, then `*` — show the user the script's stderr, or the error when it failed to start, and stop. `*` covers `1` and every undocumented code.

## Prerequisites

When the scripts need prerequisites beyond their runtime — modules, tools — the skill's first step runs `check-prerequisites.<ext>`, so the agent learns up front whether the skill can work. The script checks every such prerequisite and never the runtime itself: a missing runtime shows up as the script failing to start, which `*` covers.

```markdown
### 1. Check prerequisites

Run `<command>`. Act on the script's exit code by this playbook:

- `0` — continue.
- `2` — a prerequisite is missing; offer the user to install what stderr names. Once installed, run this step again — at most once; when it still exits non-zero, show the user the script's stderr and stop.
- `*` — show the user the script's stderr, or the error when it failed to start, and stop.
```
