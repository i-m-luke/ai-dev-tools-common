# README

This README is for whoever **edits** the skill (human or agent): `SKILL.md` does not point here, so this
file never loads into the consuming agent's context — it rides only on the editor's attention.

## Editing guidelines

### Keep the skill stack-agnostic

Describe the process generically — layout definition -> wired code ->
behavior — and derive everything from the code that is actually present.
Never bake in a specific UI framework, platform, or language: no
framework-named examples, no stack-specific vocabulary.

Agnosticism is preserved by keeping such content out, not by adding a rule
inside `SKILL.md` that asks for it. A "stay agnostic" instruction in the body
would be a no-op for the running agent (it already reads the code that is
there) while still spending context load — so record the intent here instead.
