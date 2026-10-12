# Agents

**Before your first reply, read `AGENTS-SHARED.md`** by its path (symlink, glob skips it); it is part
of these instructions. If it can't be read, tell the user.

## Skills

A skill folder holds only what the invoking agent needs; an agent may read any file in it. Put
notes for humans (maintainers, setup) in `docs/skills/<skill>.md`, never a README in the skill folder,
and list the doc in `docs/skills/index.md`.

## Versioning

On finishing work that changes shipped plugin content (`skills/`, `agents/`), recommend a semver bump level for `version` in `.plugin/plugin.json`; apply it once the user approves.
