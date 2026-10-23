# Scripts

A script is a stateless function: its behaviour depends only on its input, and it keeps no state of its own between runs. It runs without interaction: it reads no input while it runs, and communicates with the agent only through its exit code and its [output](#output).

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
  `::result::{"path":"out/issues.csv","count":12}`, on exit code `0` or `21` to `63`. A script that has nothing to return prints no `::result::` line.
- **Log** — every other stdout line, whoever writes it: the script, a library or a child process.
- **Errors** — on stderr.
- **Files** — in the run folder that `assets/instruction-blocks/artifacts.md` describes. A script that starts a skill run creates the run folder.

## Exit codes

The code's range alone tells the agent where the outcome is: the result on stdout, or the error on stderr. Expected outcomes take one range, `20` to `63`: `20` is the expected failure, the rest return a result.

- `0` — Success: the script did what it is for; the result, when the script returns one, is on stdout. The skill goes on as usual.
- `1` — Unexpected failure: an unhandled error. End every unhandled error with 1 — most runtimes do so on their own — so 1 never means more.
- `20` — Expected failure; stderr says which. The agent acts on it differently from an unexpected failure.
- `21` to `63` — Other expected outcomes, each documented in the help with its result on stdout. They change the skill's course.
- Any other code — Unexpected failure, like `1`.

The range starts at 20 and ends at 63 so that a code the runtime or shell exits with on its own is never read as an expected outcome: they claim 2 (Python, Go, Bash), 3 to 14 (Node.js) and 64 and up (pwsh, the Python launcher, Bash signals), and Unix keeps only the low 8 bits, so a code above 255 wraps around. Before you document a code, check in the documentation of the script's runtime that it never exits with that code on its own; when it does, pick another code from the range.

## Help

Document each script inside it, through the language's native help mechanism, in this outline:

1. **Purpose** — what the script does.
2. **Input** — each parameter, or that the script takes none.
3. **Result** — the shape of the result JSON for each exit code that returns one, or that the script returns none.
4. **Stderr** — what the script writes there.
5. **Exit codes** — see [Exit codes](#exit-codes) section

The skill names the command that prints the help; the help is the only documentation of what the script returns and which errors it reports.

## Running scripts

Act on every script run by a playbook keyed by exit code: Starting by `0`, then a row for each documented code from `20` up, then `*` — show the user the script's stderr, or the error when it failed to start, and stop. `*` covers `1` and every undocumented code.

## Prerequisites

When the scripts need prerequisites beyond their runtime — modules, tools — the skill's first step runs `check-prerequisites.<ext>`, so the agent learns up front whether the skill can work. The script checks every such prerequisite and never its own runtime: a missing runtime shows up as the script failing to start, which `*` covers. When the runtime itself is a prerequisite — a tool such as dotnet-script — write `check-prerequisites` in a language the users already have, PowerShell by default, and let it check the runtime too; it is the only script of the skill that may differ in language.

```markdown
### 1. Check prerequisites

Run `<command>`. Act on the script's exit code by this playbook:

- `0` — continue.
- `20` — a prerequisite is missing; offer the user to install what stderr names. Once installed, run this step again — at most once; when it still exits non-zero, show the user the script's stderr and stop.
- `*` — show the user the script's stderr, or the error when it failed to start, and stop.
```
