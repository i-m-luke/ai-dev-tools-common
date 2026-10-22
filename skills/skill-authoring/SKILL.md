---
name: skill-authoring
description: Use when creating a skill or changing what one does — its instructions, description, scripts or other files. Load it before loading the skill you create or edit.
metadata:
  credits:
    skill: writing-for-agents
    author: Matt Pocock
    organisation: mattpocock
    url: https://github.com/mattpocock/skills/tree/main/skills/productivity/writing-for-agents
---

Conventions for authoring a skill, so that every skill follows one contract.

Run `/writing-for-agents` skill (authored by Matt Pocock) — it covers writing any document an agent reads. When the `writing-for-agents` skill is missing or cannot be invoked, tell the user and continue without it. Where its instructions conflict with this skill's, this skill's win.

Write skills in English, like any context an agent reads.

## Skill type

Every skill is one of these types, each with its own guidelines:

- **Workflow skill** — walks the agent through ordered steps towards a goal; usually categorizes as either _explicit_ or _hybrid_. Read `references/workflow-skills.md` when you create or change a workflow skill.
- **Tool skill** — gives the agent a set of helpers, each run as a command; like a workflow skill it holds steps, but each command has its own. Usually categorizes as _implicit_; such a skill is a candidate for an MCP server, so point that out to the user. Read `references/tool-skills.md` when you create or change a tool skill.
- **Convention skill** — rules the agent returns to on demand while it works; usually categorizes as _implicit_. Read `references/convention-skills.md` when you create or change a convention skill.

## Skill categorization

What characteristics suit the requirements the most? Compare the three categories below and pick the one that fits; the rest of this skill refers to them by name.

### Explicit

- **Characteristics**: runs only when the user invokes it; neither the agent nor another skill can start it. Its frontmatter sets `disable-model-invocation: true`.
- **When to choose**: the user alone decides when the skill runs, e.g. a workflow that changes things or costs many tokens. It costs no context, as its description is never loaded, and its invocation is deterministic: it runs exactly when the user invokes it, never on the agent's guess.
- **Naming**: a verb phrase, e.g. `write-poem`.
- **Description**: starts with `Use when`, followed by a one-sentence summary for the human who picks the skill.
- **How others call it**: they cannot; a skill that needs it tells the user to run `/<skill>`.

### Implicit

- **Characteristics**: model invocation stays on — `disable-model-invocation` stays unset — so the agent loads the skill on its own for every task its description matches, and other skills can run it.
- **When to choose**: the agent must decide on its own when to load the skill — a [convention skill](#skill-type), or a [tool skill](#skill-type) the agent reaches for whenever a task needs it. Its description stays loaded on every turn, so the reach must be worth it.
- **Naming**: a noun phrase, e.g. `poem-writing`.
- **Description**: starts with `Use when`, followed by every distinct situation the skill applies to, one trigger each, e.g. `Use when writing, reviewing or refactoring C# code — classes, constructors, method calls, file and namespace layout.` The agent reads it to decide whether to load the skill, and the uniform leading phrase makes it read as a trigger condition.
- **How others call it**: as described in [Calling another skill](#calling-another-skill).

### Hybrid

- **Characteristics**: half of each — _implicit_ in its settings, so other skills' instructions can run it; _explicit_ in behaviour, as it runs only on its literal trigger.
- **When to choose**: the user runs it by hand and other skills must be able to run it too, e.g. sending a notification.
- **Naming**: same as [Explicit](#explicit).
- **Description**: starts with `Use ONLY when`, followed by its triggers and nothing else, e.g. `Use ONLY when the literal text "/notify" appears in the request or instructions — never otherwise, whatever the task.`. Its purpose belongs in the skill body.
- **How others call it**: as described in [Calling another skill](#calling-another-skill).

## Frontmatter

Start the `description` and `name` as its [category](#skill-categorization) prescribes.

Write frontmatter values without an unquoted `:` — it makes the YAML invalid and the skill fails to load. Use an em dash (—) instead.

## Calling another skill

Call another skill with three sentences, filled in. The middle one depends on whether the call is required or optional:

- **Required** — the calling skill cannot deliver its result without the called one, so the agent stops:
  > Run `/<skill>` skill …. When the `<skill>` skill is missing or cannot be invoked, tell the user and stop. Where its instructions conflict with this skill's, this skill's win.
- **Optional** — the called skill only improves the result, so the agent goes on:
  > Run `/<skill>` skill …. When the `<skill>` skill is missing or cannot be invoked, tell the user and continue without it. Where its instructions conflict with this skill's, this skill's win.

Write no fallback copy of the called skill's instructions: a copy drifts from the original.

## Standard phrases

Point at a skill's files and decisions with these phrases, so the agent recognises each pointer:

- reference — `Read references/<file> when <condition>.`
- template — `Fill in assets/<file> …` when the agent completes it, or `Use assets/<file> as …` when it uses the file as it is.
- script — `Run <exact command> …`.
- playbook — `Act on the script's exit code by this playbook:`, followed by one `<outcome>` — `<action>` item per outcome.

## Positive instructions

Write each instruction as what the agent should do, not what it must avoid: "write one-line comments", not "don't write long comments". Naming the unwanted behaviour puts it into the agent's context and makes it more likely.

Write a prohibition only where no positive phrasing exists, and pair it with what to do instead. Example: a hybrid skill's description ends with "— never otherwise, whatever the task"; without it, trigger evals showed the agent loading the skill for requests that merely resemble its task.

## Skill folder

A skill folder holds `SKILL.md` and, as needed:

- `agents/` — per-agent metadata, e.g. `openai.yaml`.
- `scripts/` — the skill's scripts (see [Scripts](#scripts)).
- `assets/` — files the skill uses as they are or fills in, e.g. a document or HTML template.
- `references/` — further instructions the agent reads when a step calls for them.

`SKILL.md` mentions every file in `assets/` and `references/` by its path in the skill folder (e.g. `references/TERMS.md`), together with when to use it: the mention is the agent's only way to the file. Keep `SKILL.md` a short overview: move detail that only some tasks need into a reference.

## Scripts

Scripts are the skill's own tools — small programs the agent runs to do the mechanical work, while it keeps the judgement.

When designing a skill, go through its steps and ask of each instruction whether a script can do it. Aim for scripts to carry about 80 % of the work, leaving the agent the 20 % that needs judgement — every step moved to a script is cheaper, faster and repeatable. Every mechanical instruction or sequence of instructions — one whose outcome is fixed by its input, such as calling an API, parsing, transforming or validating files — runs as a script, so the agent spends no judgement or tokens on it and its result never drifts.

Design cannot foresee every split. Once the skill's scripts work, review its steps again, together with its eval transcripts when there are any. Where the agent still does mechanical work, e.g. composes ad-hoc commands or reshapes a script's result, propose moving it into a script. Where a script fakes judgement through flags, propose handing it back to the agent. Agree each such deviation from the specification with the user before making it.

Read `references/scripts.md` when a skill gets a script or you write, change or call one; it holds the contract every script follows, in any language. Read `references/powershell-scripts.md` when the skill's scripts are in PowerShell; it works the contract out in that language.

## Artifacts

A skill's artifacts folder holds the files it produces for its own work or for the user, as `assets/instruction-blocks/artifacts.md` lays it out. A script that produces a run's output creates the run folder and returns its path in its result; a script that writes into an existing run folder receives the path from its caller.

## Instruction blocks

Rules that bind the agent running a skill live in instruction blocks in `assets/instruction-blocks/`: the running agent never loads this skill, so each skill carries the blocks it needs. Read each block that applies to the skill, keep the skill's own instructions consistent with its rules, and place it in the skill verbatim, with each `{{…}}` filled in — `{{skill}}` with the skill's name — and each `<…>` kept for the running agent to fill in:

- A skill with scripts — fill in `assets/instruction-blocks/scripts.md` as its `## Scripts` chapter, beside `## Steps`.
- A skill with PowerShell scripts — use `assets/instruction-blocks/scripts-powershell.md` as the first paragraph of that chapter.
- A skill that writes files of its own, or whose scripts take a `<Noun>Path` parameter — fill in `assets/instruction-blocks/artifacts.md` as its `## Artifacts` chapter.

When you change a skill, bring the blocks it carries in line with these files, and add the ones that now apply.
