# README

These notes are for anyone modifying this skill. They are intentionally kept out of
[`SKILL.md`](SKILL.md), which holds only the instructions the invoking agent needs.

## Why this skill is model-invokable

This skill is the shared source of truth for user-invoked wrappers that run it. An agent can only reach a
skill that carries a `description`: with `disable-model-invocation: true` the skill
loses its description, and nothing but a human typing its name can invoke it.

## Editing guidelines

### Keep the skill stack-agnostic

Describe the process generically — layout definition -> wired code ->
behavior — and derive everything from the code that is actually present.
Never bake in a specific UI framework, platform, or language: no
framework-named examples, no stack-specific vocabulary.
