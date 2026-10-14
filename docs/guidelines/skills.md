# Skills

The shipped skills in [`skills/`](../../skills) follow the conventions of the
[`skill-writing`](../../skills/skill-writing/SKILL.md) skill. This page adds what holds only in this
repo; the [script tests](../verification/script-tests.md) enforce it.

## Invocation

Skills are explicit by default. A convention skill that stays implicit is listed, with the reason,
in [`implicit-skills.yaml`](../../script-tests/skill-frontmatter/implicit-skills.yaml).

## Skill descriptions

The script tests check that every description starts with "Use when" or "Use ONLY when".

## Skill folder

The script tests check the folder layout and that `SKILL.md` mentions every file in `assets/` and
`references/`.

## Scripts

The Pester tests of a skill's scripts live in `script-tests/<skill>/` (see
[script tests](../verification/script-tests.md)); the script tests check that each script has them.

## Workflow skills

The script tests check the step numbering.
