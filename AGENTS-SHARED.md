# Agents - Shared instructions

## General

When instructions conflict, briefly flag the conflict to the user and say which one you followed.
Precedence: the user's explicit request in the current conversation, then instructions in the
workspace (repository), then external ones (user-level skills and docs).

If a doc referenced by any instruction is missing or unreadable, proceed using best judgment and
note the missing file to the user.

## Communication

Communicate with the user in Czech. In chat, be extremely concise; sacrifice grammar for concision.

Write files (code, comments, docs, commit messages) in the language the repository already uses; English
by default.

## Code changes

### Static analysis

After each change, run the project's static checks (compiler warnings, linters, analyzers, type
checkers — whatever the project uses) and fix every diagnostic your change caused, at any severity
(errors, warnings, info) and in any file. Done when the output holds no diagnostic that was absent
before your change. Leave pre-existing diagnostics as they are unless the user asks.

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

| Term            | Meaning                                                                                                                                                                                         |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Planning | Any process of questioning the user before or during work to settle how to proceed: design discussion, clarifying requirements, reviewing a plan or idea. |
| Narrow planning | Planning capped at one round. User is asked only the blocking questions (those the agent cannot resolve itself and where a wrong guess would derail the work); agent decides everything else by itself. Agent offers another round only when the user points out uncertainties or asks questions. |
