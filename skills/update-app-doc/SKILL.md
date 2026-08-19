---
name: update-app-doc
description: Compare an app's UI documentation against its code and bring it back in sync.
disable-model-invocation: true
---

Find the **drift** between an existing app UI document and the code, report it, and edit the document on the developer's word.

## 1. Find the document

Take the document the developer named. When none was named, search the repository for a documentation folder (`docs`, `documentation`, or a sibling of that kind) and read the headings of what you find there.

- Several candidates: list them numbered and let the developer pick.
- No candidate: report that there is nothing to update and point the developer at `write-app-doc`.

## 2. Analyse

Walk the app top-down from its UI entry point, and for every element read the code wired to it — its handler, command, or binding target — before judging what the document says about it. Behaviour comes from the code that runs, so treat a label, a control name, or the document's own wording as a claim to verify, never as evidence.

The analysis closes when both directions are covered:

- every interactive element in the code has an entry in the document,
- every claim in the document traces to code you have read.

## 3. Report

Report before you touch the document. Number the rows continuously across the tables, so the developer can answer with numbers, and drop a table that has no rows.

Link every place as a clickable absolute path with forward slashes and a line number — `[MainWindow.xaml](C:/proj/src/MainWindow.xaml:42)` — and name a chapter by its link plus its anchor: `[Main window](C:/proj/docs/app.md:42) (#main-window)`.

**Mismatches** — the document describes behaviour the code does not have.

| #   | Chapter | Finding |
| --- | ------- | ------- |

**Proposed additions** — behaviour in the code the document leaves out.

| #   | Proposed chapter | Proposed content, why it belongs, and where it lives in the code |
| --- | ---------------- | ---------------------------------------------------------------- |

**Suspected code defects** — the document states an intent and the code contradicts it in a way that reads as a bug. These stay a report to the developer and never become an edit: writing the current behaviour into the document would bury the bug.

| #   | Code | What the document states | What the code does |
| --- | ---- | ------------------------ | ------------------ |

Close the report by offering three ways to answer: apply everything, apply the numbers listed, or apply nothing.

## 4. Apply what the developer approved

Run a `/document-app` session over the approved rows and the chapters they name, following its method and its format for the edits.

Carry the document's machinery along with the text: table-of-contents entries, heading anchors, and cross-references, with images following `document-app`'s image rules.

## 5. Close

Report the chapters you changed, each as a clickable link. Where a chapter's screenshot now shows a UI the code no longer produces, list it under screenshots to recapture — the developer captures those.
