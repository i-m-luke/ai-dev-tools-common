---
name: skill-writing
description: Use when creating a skill or changing what one does — its instructions, description, scripts or other files. Load it before loading the skill you create or edit.
metadata:
  credits:
    skill: writing-for-agents
    author: Matt Pocock
    organisation: mattpocock
    url: https://github.com/mattpocock/skills/tree/main/skills/productivity/writing-for-agents
---

Conventions for writing a skill.

Run `/writing-for-agents` — it covers writing any document an agent reads; where it conflicts with these conventions, these win. When the `writing-for-agents` skill is missing or cannot be invoked, tell the user and stop.

Write skills in English, like any context an agent reads.

## Invocation type

Every skill is one of three types; the rest of this skill refers to them by name.

- **explicit**:
  > Runs only when the user invokes it. Both of the following hold:
  > a. its `agents/openai.yaml` sets `policy.allow_implicit_invocation: false`
  > b. its `disable-model-invocation` is set to `true`
  > When only one of them holds, the skill's invocation is in conflict — point it out to the user.
- **implicit**:
  > Loads on its own for every task it touches, e.g. the conventions of a language or an architecture.
- **hybrid**:
  > Is half of each: _implicit_ in its settings, so other skills' instructions can run it; _explicit_ in behaviour, as it runs only on its literal trigger. Its description lists its triggers and nothing else, e.g.
  > `Use ONLY when the literal text "/notify" appears in the request or instructions — never otherwise, whatever the task.` Its purpose belongs in the skill body, and callers run it as `Run /<skill> …`.

## Naming

Name a skill after its [invocation type](#invocation-type): an explicit or hybrid skill by a verb
phrase, e.g. `write-poem`; an implicit skill by a noun phrase, e.g. `poem-writing`.

## Skill descriptions

A skill's `description` starts with "Use when" — e.g. `Use when asked to message or notify the user
remotely.` — or, for a hybrid skill, "Use ONLY when". The description is the
pointer an agent reads to decide whether to load the skill, and a uniform leading phrase makes it
read as a trigger condition.

Write frontmatter values without an unquoted `:` — it makes the YAML invalid and the skill fails to
load. Use an em dash (—) instead.

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
file.

## Scripts

When designing a skill, go through its steps and ask of each one whether a script can do it. Aim for
scripts to carry about 80 % of the work, leaving the agent the 20 % that needs judgement — every
step moved to a script is cheaper, faster and repeatable.

A step whose outcome is fixed by its input — calling an API, parsing, transforming or validating
files — runs as a script, so the agent spends no judgement or tokens on it and its result never
drifts. The script lives in the skill's `scripts/` folder, is written in PowerShell and runs without
interaction; it reports through its exit code and stderr. The step that runs it names the exact
command — `pwsh -NoProfile -File <this skill's folder>/scripts/<script>.ps1 …`, with `powershell` in
place of `pwsh` when pwsh is missing — and acts on the result by a playbook keyed by exit code.
When neither `pwsh` nor `powershell` is available, tell the user and ask whether to install
PowerShell or write the script in another language.
Pester tests cover every script.

## Artifacts

Files a skill produces for its own work or for the user — reports, previews, state — go to
`.artifacts/<skill>/<yyyyMMdd-HHmmss>/` in the workspace root, one folder per run. The skill's script
creates the folder and prints its path for the agent; in a skill without scripts, the agent creates
it. A script keeps its state in `state.json` in that folder; state that must outlive a run lives in
`.artifacts/<skill>/state.json`, an exception the skill justifies in its body. Output that belongs in
the user's repository, such as documentation, goes where the skill writes it.

## Workflow skills

A workflow skill — one that walks the agent through ordered steps — puts those steps under a
`## Steps` chapter, so the sequence stands apart from the reference it consults. Each step is a
chapter of its own, `### N. <action>`, named by what the agent does. Reference used by a single
step, such as a playbook, lives inside that step; reference shared by several steps gets a chapter
beside `Steps`.
