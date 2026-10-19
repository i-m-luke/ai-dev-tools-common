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

Run `/writing-for-agents` — it covers writing any document an agent reads. When the
`writing-for-agents` skill is missing or cannot be invoked, tell the user and stop. Where its
instructions conflict with this skill's, this skill's win.

Write skills in English, like any context an agent reads.

## Skill type

Every skill is one of two types, each with its own template:

- **Workflow skill** — walks the agent through ordered steps towards a goal; usually explicit or hybrid. A tool skill, one built around scripts, is a workflow skill too. Read `references/workflow-skills.md` when you create or change a workflow skill.
- **Convention skill** — rules the agent returns to on demand while it works; usually implicit. Read `references/convention-skills.md` when you create or change a convention skill.

## Skill categorization

What characteristics suit the requirements the most? Compare the three categories below and pick
the one that fits; the rest of this skill refers to them by name.

### Explicit

- **Characteristics**: runs only when the user invokes it; neither the agent nor another skill can
  start it. Both settings hold: `disable-model-invocation: true` in `SKILL.md` and
  `policy.allow_implicit_invocation: false` in `agents/openai.yaml`. When only one of them holds,
  the skill's invocation is in conflict — point it out to the user.
- **When to choose**: the user alone decides when the skill runs, e.g. a workflow that changes
  things or costs many tokens. It costs no context, as its description is never loaded.
- **Naming**: a verb phrase, e.g. `write-poem`.
- **Description**: starts with `Use when`, followed by a one-sentence summary for the human who picks the skill.
- **How others call it**: they cannot; a skill that needs it tells the user to run `/<skill>`.

### Implicit

- **Characteristics**: model invocation stays on — neither setting is set — so the agent loads the
  skill on its own for every task its description matches, and other skills can run it.
- **When to choose**: the skill applies to every task it touches, e.g. the conventions of a language
  or an architecture. Its description stays loaded on every turn, so the reach must be worth it.
- **Naming**: a noun phrase, e.g. `poem-writing`.
- **Description**: starts with `Use when`, followed by every distinct situation the skill applies to, one trigger each. The agent reads it to decide whether to load the skill, and the uniform leading phrase makes it read as a trigger condition.
- **How others call it**: as described in [Calling another skill](#calling-another-skill).

### Hybrid

- **Characteristics**: half of each — _implicit_ in its settings, so other skills' instructions can
  run it; _explicit_ in behaviour, as it runs only on its literal trigger.
- **When to choose**: the user runs it by hand and other skills must be able to run it too, e.g.
  sending a notification.
- **Naming**: a verb phrase, e.g. `notify`.
- **Description**: starts with `Use ONLY when`, followed by its triggers and nothing else, e.g. `Use ONLY when the literal text "/notify" appears in the request or instructions — never otherwise, whatever the task.`. Its purpose belongs in the skill body.
- **How others call it**: as described in [Calling another skill](#calling-another-skill).

## Frontmatter

Start the `description` and `name` as its [category](#skill-categorization) prescribes.

Write frontmatter values without an unquoted `:` — it makes the YAML invalid and the skill fails to
load. Use an em dash (—) instead.

## Calling another skill

Call another skill with these three sentences, filled in:

> Run `/<skill>` …. When the `<skill>` skill is missing or cannot be invoked, tell the user and stop. Where its instructions conflict with this skill's, this skill's win.

Write no fallback copy of the called skill's instructions: the calling skill depends on it as on a
prerequisite, and a copy drifts from the original.

## Standard phrases

Point at a skill's files and decisions with these phrases, so the agent recognises each pointer:

- reference — `Read references/<file> when <condition>.`
- template — `Fill in assets/<file> …` when the agent completes it, or `Use assets/<file> as …`
  when it uses the file as it is.
- script — `Run <exact command> …`.
- playbook — `Act on the script's exit code by this playbook:`, followed by one `<outcome>` —
  `<action>` item per outcome.

## Wording

Phrase every instruction in a skill as the behaviour to take — "write one-line comments" rather than
a ban on long ones: a prohibition names the unwanted behaviour and makes it more likely. A hard
guardrail with no positive phrasing stays a prohibition, paired with the behaviour to take instead.
One such guardrail is the closing "— never otherwise, whatever the task" in the description of a
hybrid skill: without it, trigger evals showed the agent loading the skill for requests
that merely resemble its task.

## Skill folder

A skill folder holds `SKILL.md` and, as needed:

- `agents/` — per-agent metadata, e.g. `openai.yaml`.
- `scripts/` — the skill's scripts (see [Scripts](#scripts)).
- `assets/` — files the skill uses as they are or fills in, e.g. a document or HTML template.
- `references/` — further instructions the agent reads when a step calls for them.

`SKILL.md` mentions every file in `assets/` and `references/` by its path in the skill folder (e.g.
`references/TERMS.md`), together with when to use it: the mention is the agent's only way to the
file. Keep `SKILL.md` a short overview: move detail that only some tasks need into a reference.

## Scripts

When designing a skill, go through its steps and ask of each one whether a script can do it. Aim for
scripts to carry about 80 % of the work, leaving the agent the 20 % that needs judgement — every
step moved to a script is cheaper, faster and repeatable. A step whose outcome is fixed by its
input — calling an API, parsing, transforming or validating files — runs as a script, so the agent
spends no judgement or tokens on it and its result never drifts.

Read `references/scripts.md` when a skill gets a script or you write, change or call one; it holds
the contract every script follows, in any language. Read `references/powershell-scripts.md` when
the skill's scripts are in PowerShell; it works the contract out in that language.

## Artifacts

Files a skill produces for its own work or for the user — reports, previews, state files — go to
`.artifacts/<skill>/<yyyyMMdd-HHmmss>/` in the workspace root, one folder per run. The skill's script
creates the folder and returns its path in its result; in a skill without scripts, the agent creates
it. A script that writes there receives the path from its caller. Output that belongs in the user's
repository, such as documentation, goes where the skill writes it.
