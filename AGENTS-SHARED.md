# Agents - Shared instructions

## General

Start your first reply in a conversation with the line `AGENTS-SHARED.md: ✓`; it shows the user
this file was loaded.
When instructions conflict, briefly flag the conflict to the user and say which one you followed.
Precedence: the user's explicit request in the current conversation, then instructions in the
workspace (repository), then external ones (user-level skills and docs).

If a doc referenced by any instruction is missing or unreadable, proceed using best judgment and
note the missing file to the user.

When given a **playbook**, pick your next step by it: on an outcome matching a key, run the bound
action; with no match, use the `*` key if present, else ask the user.

## Communication

Communicate with the user in the language set in the conversation or implied by context — the one
the user writes in and prefers. In chat, be extremely concise; sacrifice grammar for concision.

Planning is exhausted once the user has answered every question and the answers raise no new one.
Only then close it with a plan summary for approval, in a reply whose sole question is that
approval; start implementing only once the user approves.

### Shared files

`.artifacts/` in the repository root is the file exchange between you and the user: put every file
meant for the user there, and look there for files the user refers to. When you create
the folder, check that `.gitignore` ignores it; if it does not, tell the user and leave
`.gitignore` to them.

## Writing docs

Describe the **essence** — what the thing is for and the rule it upholds — in as few sentences as
it needs, optimally one or two. Describe behaviour at a high level; add implementation details
only when the user asks or when the behaviour cannot be understood without them. Applies to every
human-facing doc in any repo: markdown docs, ADRs, and code doc comments alike. Docs with a
dedicated skill (e.g. agent instructions, app UI docs) follow that skill instead.

## Code changes

Write code, comments, docs and commit messages in the repo's existing language; English by default.

### Quality assurance

After each change, run the project's static analysis (e.g. linters, compiler warnings) and tests.
Done when the output holds no diagnostic (any severity, any file) or red test absent before your
change; leave pre-existing ones unless the user asks.

### Committing

Leave changes in the working tree; commit only when the user asks. Offer a commit only on finishing
a step listed in a multi-step plan agreed during planning — not after a single reply or edit.

## Glossary

Read [glossary.md](agents-shared/glossary.md) when you meet an unfamiliar term (e.g. a **bolded** one in these
instructions) or need to align terminology with the user.

## Roles

Read [roles.md](agents-shared/roles.md) when the user assigns you a role (e.g. `Roles: x, y`, or in plain
words such as "do this as a robot").

## Triage labels

Read [triage-labels.md](agents-shared/triage-labels.md) before applying a triage label — it holds the canonical label
strings.
