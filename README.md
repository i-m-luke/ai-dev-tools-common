# README

The repository conaints agent tools (skills, agents, etc.) bundled as a plugin.

## Skills

- Installation: Install skills at once by running 'npx skills add \<floder or git repo url\>' command
- Updating: Update the skills by 'npx skills update' command
- Docs: [docs/skills](docs/skills/index.md)

## AGENTS-SHARED

`AGENTS-SHARED.md` holds user preferences shared across projects. Include it in a project via a symlink:

```powershell
# Windows (needs Developer Mode or an elevated shell)
New-Item -ItemType SymbolicLink -Path <path-to-the-project>AGENTS-SHARED.md -Target <path-to-this-repo>\AGENTS-SHARED.md
```

```sh
# Linux / macOS
ln -s <path-to-this-repo>/AGENTS-SHARED.md <path-to-the-project>AGENTS-SHARED.md
```

Adding `AGENTS-SHARED.md` to the project's `.gitignore` is recommended, so it doesn't pollute the repo for other developers.

Load this context file by this instruction added at the top of your AGENTS.md file:

```text
**Before your first reply, read`AGENTS-SHARED.md`** by its path (symlink, glob skips it); it is part
of these instructions. If it can't be read, tell the user.
```

## Verification

Two kinds of checks verify the repo:

- [Script tests](docs/verification/script-tests.md): Pester tests of the scripts the skills ship. Fast and
  free (no token consumption), run them whenever you change a script.
- [Evals](docs/verification/evals.md): run Copilot CLI against the skills and agent instructions and grade its
  behaviour. They consume tokens, so run only the evals for what you changed.
