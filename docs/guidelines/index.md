# Guidelines

Conventions for writing the shipped skills in [`skills/`](../../skills).

## Skill descriptions

A skill's `description` starts with "Use when" — e.g. `Use when asked to message or notify the user
remotely.` — or, for a skill explicit by design (below), "Use ONLY when". The description is the
pointer an agent reads to decide whether to load the skill, and a uniform leading phrase makes it
read as a trigger condition. The script tests enforce it.

Avoid an unquoted `: ` inside a frontmatter value: it makes the YAML invalid and the skill fails to load.
Prefer an em dash (—).

### Skills explicit by design

An **implicit skill** designed to run only on request — left implicit merely so other skills can run
it from their instructions — has a description that lists its triggers and nothing else, e.g.
`Use ONLY when the literal text "/notify" appears in the request or instructions — never otherwise, whatever the task.`
Its purpose belongs in the skill body, and callers run it as `Run /<skill> …`.

## Workflow skills

A workflow skill — one that walks the agent through ordered steps — puts those steps under a
`## Steps` chapter, so the sequence stands apart from the reference it consults. Each step is a
chapter of its own, `### N. <action>`, named by what the agent does. Reference used by a single
step, such as a playbook, lives inside that step; reference shared by several steps gets a chapter
beside `Steps`.
