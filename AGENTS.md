# Agents

**Before your first reply, read `AGENTS-SHARED.md`** by its path (symlink, glob skips it); it is part
of these instructions. If it can't be read, tell the user and continue using only the instructions
in this file.

## Shipped skills

A skill folder holds only what the invoking agent needs; an agent may read any file in it. Put
notes for humans (maintainers, setup) in `docs/skills/<skill>.md`, never a README in the skill folder,
and list the doc in `docs/skills/index.md`.

## Versioning

On finishing work that changes shipped plugin content (`skills/`, `agents/`), recommend a semver bump level for `version` in `.plugin/plugin.json`; apply it once the user approves. If the user declines, leave `version` unchanged and don't ask again for the same change set.

- **major** — breaking change to a skill's or agent's interface (rename, removal, changed invocation).
- **minor** — new skill or agent, or a new capability in an existing one.
- **patch** — fix or wording tweak to existing content.
