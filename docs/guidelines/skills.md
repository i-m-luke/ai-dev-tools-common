# Skills

The shipped skills in [`skills/`](../../skills) follow the conventions of the
[`skill-authoring`](../../skills/skill-authoring/SKILL.md) skill. This page adds what holds only in this
repo; the [repo checks](../verification/repository-checks.md) enforce it.

## Invocation

Skills are explicit by default: `disable-model-invocation: true` in `SKILL.md` and
`policy.allow_implicit_invocation: false` in `agents/openai.yaml`, both checked by the repo checks.
A convention skill that stays implicit is listed, with the reason,
in [`implicit-skills.yaml`](../../implicit-skills.yaml).

## Skill descriptions

The repo checks verify that every description starts with "Use when" or "Use ONLY when".

## Skill folder

The repo checks verify the folder layout and that `SKILL.md` mentions every file in `assets/` and
`references/`.

## Scripts

The Pester tests of a skill's scripts live in `tests/script-tests/<skill>/` (see
[script tests](../verification/script-tests.md)); the repo checks verify that each script has them.

## Workflow skills

The repo checks verify the step numbering.
