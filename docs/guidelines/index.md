# Guidelines

## Skill descriptions

A skill's `description` starts with "Use when" — e.g. `Use when asked to message or notify the user
remotely.` The description is the pointer an agent reads to decide whether to load the skill, and a
uniform leading phrase makes it read as a trigger condition. The script tests enforce it.

Avoid an unquoted `: ` inside a frontmatter value: it makes the YAML invalid and the skill fails to load.
Prefer an em dash (—).
