# Agents - Shared instructions

## General

Start your first reply in a conversation with the line `AGENTS-SHARED.md: ✓`; it shows the user
this file was loaded.

When instructions conflict, briefly flag the conflict to the user and say which one you followed.
Precedence: the user's explicit request in the current conversation, then instructions in the
workspace (repository), then external ones (user-level skills and docs).

If a doc referenced by any instruction is missing or unreadable, proceed using best judgment and
note the missing file to the user.

## Communication

Communicate with the user in Czech. In chat, be extremely concise; sacrifice grammar for concision.

Planning is exhausted once the user has answered every question and the answers raise no new one.
Only then close it with a plan summary for approval, in a reply whose sole question is that
approval; start implementing only once the user approves.

### Shared files

`.artifacts/` in the repository root is the file exchange between you and the user: put every file
meant for the user there, and look there for files the user refers to. When you create
the folder, check that `.gitignore` ignores it; if it does not, tell the user and leave
`.gitignore` to them.

## Code changes

Write (code, comments, docs, commit messages) in the language the repository already uses; English
by default.

### Quality assurance

After each change, run the project's static checks (compiler warnings, linters, analyzers, type
checkers — whatever the project uses) and its tests. Fix every diagnostic your change caused, at any
severity (errors, warnings, info) and in any file, and every test your change turned red. Done when
the output holds no diagnostic or red test that was absent before your change. Leave pre-existing
diagnostics and red tests as they are unless the user asks.

### Committing

Leave changes in the working tree and never commit unprompted. Offer a commit only when finishing a
phase of a multi-phase plan agreed with the user during planning for a larger task; a phase is one
of the plan's named steps, not a single reply or edit. For small tasks and follow-up tweaks, don't
ask — the user will say when to commit.

## Writing docs

Describe the **essence** — what the thing is for and the rule it upholds — in as few sentences as
it needs, optimally one or two. Describe behaviour at a high level; add implementation details
only when the user asks or when the behaviour cannot be understood without them. Applies to every
human-facing doc in any repo: markdown docs, ADRs, and code doc comments alike. Docs with a
dedicated skill (e.g. agent instructions, app UI docs) follow that skill instead.

## Glossary

| Term             | Meaning                                                                                                                                                                                                                                                                                                                                                                                                                           |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Planning         | Any process of questioning the user before or during work to settle how to proceed: design discussion, clarifying requirements, reviewing a plan or idea.                                                                                                                                                                                                                                                                         |
| Shallow planning | Planning kept to the fewest rounds that settle the work — ideally one, two when needed, more only exceptionally. User is asked only the blocking questions (those the agent cannot resolve itself and where a wrong guess would derail the work); agent decides everything else by itself. Agent opens another round only when answers raise new blocking questions, or when the user points out uncertainties or asks questions. |
