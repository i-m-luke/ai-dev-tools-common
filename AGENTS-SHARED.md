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

## Roles

Read `agents-shared/roles.md` when the user assigns you a role (e.g. `Roles: x, y`).

## Triage labels

Read `agents-shared/triage-labels.md` before applying a triage label — it holds the canonical label
strings.

## Glossary

- **Planning** — any questioning of the user before or during work to settle how to proceed: design
  discussion, clarifying requirements, reviewing a plan or idea.
- **Shallow planning** — planning kept to the fewest rounds that settle the work: ideally one, two when needed, more only exceptionally. Only blocking questions are asked (ones you cannot resolve yourself and where a wrong guess would derail the work); decide everything else yourself. Another round is opened only when answers raise new blocking questions, or the user points out uncertainties or asks questions.
