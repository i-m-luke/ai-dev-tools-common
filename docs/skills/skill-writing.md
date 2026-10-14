# skill-writing

These notes are for anyone modifying this skill. They are intentionally kept out of the skill folder
([`SKILL.md`](../../skills/skill-writing/SKILL.md) holds only the instructions the invoking agent
needs), so an agent can't load them.

## Why this skill is implicit

It is a convention skill: it applies to every task that creates or edits a skill, in any repo, so it
loads without being named. It builds on the external
[`writing-for-agents`](https://github.com/mattpocock/skills/tree/main/skills/productivity/writing-for-agents)
skill and runs it when available.

## Editing guidelines

### Keep the skill repo-agnostic

The skill holds conventions that hold wherever a skill is written. What holds only in this repo —
how the script tests enforce the conventions, where the approved implicit skills are listed — goes
to [`docs/guidelines/skills.md`](../guidelines/skills.md).
