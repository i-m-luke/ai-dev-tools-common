# README

These notes are for anyone modifying this skill. They are intentionally kept out of
[`SKILL.md`](SKILL.md), which holds only the instructions the invoking agent needs.

## Why this skill is model-invokable

This skill is the shared source of truth for user-invoked wrappers that run it. An agent can only reach a
skill that carries a `description`: with `disable-model-invocation: true` the skill
loses its description, and nothing but a human typing its name can invoke it.

## Editing guidelines

### Keep the reference files as the source of truth

[`references/TEMPLATE.md`](references/TEMPLATE.md) is the single source of truth for the
document's Markdown shape — title, TOC markers, anchors, image tags — and
[`references/TERMS.md`](references/TERMS.md) for the wording of UI element names. `SKILL.md`
states only the rules those files cannot show, so a shape change is an edit to the template,
and a new term or language is an edit to the terms table, not to both.

### Keep the skill stack-agnostic

Describe the process generically — layout definition -> wired code ->
behavior — and derive everything from the code that is actually present.
Never bake in a specific UI framework, platform, or language: no
framework-named examples, no stack-specific vocabulary.
