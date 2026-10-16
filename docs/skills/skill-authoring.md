# skill-authoring

These notes are for anyone modifying this skill. They are intentionally kept out of the skill folder
([`SKILL.md`](../../skills/skill-authoring/SKILL.md) holds only the instructions the invoking agent
needs), so an agent can't load them.

Authoring a skill is creating or changing the whole skill — its instructions, description,
scripts, assets and folder layout — not only its text, which "writing" would suggest.

## Why this skill is implicit

It is a convention skill: it applies to every task that creates or edits a skill, in any repo, so it
loads without being named. It builds on the external
[`writing-for-agents`](https://github.com/mattpocock/skills/tree/main/skills/productivity/writing-for-agents)
skill and runs it when available.

## Structure

`SKILL.md` is a short overview every authoring task needs: the skill categories, frontmatter, skill
types, calling other skills, standard phrases, wording, the skill folder, the aim of scripts and
artifacts. Detail that only some tasks need sits in `references/`, behind a "Read … when …" pointer:
workflow skills, convention skills, the language-agnostic script contract and its PowerShell worked
example.

## Verified facts behind the script contract

- An unhandled `throw` makes both `pwsh -File` and `powershell -File` exit with 1, and Python and
  Node.js do the same on an unhandled error — so exit code 1 cannot mean a deliberate failure, and
  expected failures start at 2.
- PSScriptAnalyzer's approved-verb rule checks function and cmdlet names only, never script file
  names, so kebab-case script names such as `check-prerequisites.ps1` raise no warning.
- The PowerShell example in `references/powershell-scripts.md` avoids two Windows PowerShell 5.1
  traps: `ConvertFrom-Json` emits a JSON array as one object (so `@(… | ConvertFrom-Json)` counts 1),
  and redirecting a native command's stderr (`2>&1`) under `$ErrorActionPreference = 'Stop'`
  terminates the script.

## Editing guidelines

### Keep the skill repo-agnostic

The skill holds conventions that hold wherever a skill is written. What holds only in this repo —
how the repo checks enforce the conventions, where the approved implicit skills are listed, where
Pester tests live — goes to [`docs/guidelines/skills.md`](../guidelines/skills.md).

### Test the authoring agent, not the wording

The [eval](../../tests/evals/skill-authoring) checks the skills an agent writes with this skill —
their files and content — never the wording of `skill-authoring` itself.
