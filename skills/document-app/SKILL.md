---
name: document-app
description: Document an application's UI, functionality and purpose from the code. Use when writing app UI documentation, when revising it after a code change, or when another skill needs these conventions.
---

Document the application's UI, functionality and purpose **based on the code**.

## Derive everything from the code

Describe the app **top-down**: start at the highest-level screen (main window, page) and only then descend to sections, and then to smaller components.

Derive every description from the code, so the document reports what the app does, not what its labels suggest:

- Start at the UI entry point — app startup, main window, or root page — and read its layout definition. If the app has more than one top-level window, ask the user which one is the main one and start there.
- For each container, identify all its child regions before descending into any of them.
- For each element, follow the code wired to it — its handler, command, or binding target — and state what that code actually does.
- Account for every interactive element: a control whose behavior you have not read in the code is a gap to resolve, not a blank to fill from its label. When the wired code is missing or cannot be located, mark it in the document as **[Unknown behavior — unable to determine based on code]** rather than inferring behavior from the label.

## Lay out the document

Scaffold a new document from [`references/TEMPLATE.md`](references/TEMPLATE.md) and lay it out as this sequence of chapters:

- **Introduction** — what this document covers.
- **About the application** — what the app is for and how work reaches it.
- **Screen chapters** — the UI and controls of each screen, top-down.
- **Application settings** — placed here, before behavior, so the behavior chapters can refer to it.
- **Behavior chapters** — named after the user task they serve (`Importing a file`, `Running a job`), never after the screen the task happens on.

A screen chapter states what an element is and what one operation of it does; a behavior chapter carries the flows, states, conditions and rules that span more than one element — put a borderline case in behavior.

## Fill the chapters

Document the screens this way: give the screen a short intro — "The main window consists of these parts:" — then break a complex layout into logical sections. Label each part `A`, `B`, `C`… keyed to the screen's screenshot, and list them as: **bold part name (part A):** its purpose, then a link to the section that covers it in depth.

Document the smaller UI components this way: describe each element (button, tree, menu item…) by its purpose, function and behavior, based on the code attached to it.

Document the application's global settings and preferences as a chapter of options rather than as a screen — no layout, no parts, no screenshot. Give each option its effect, its allowed values, the condition under which it is available, and when and how a change is stored. Options that belong to a single screen or task stay documented where they live.

## Cross-reference

A cross-reference is how one meaning stays in one chapter instead of being retold in another. Link on the first mention within a chapter and leave the later mentions plain, in these cases:

- An element whose full behavior lives in a behavior chapter links to it, and that chapter links back to the element that starts the task.
- A setting that gates an element, a task, or a rule is linked from wherever that condition is stated.
- Any other chapter you name in the text is linked where you name it: `(see [Main menu bar](#main-menu-bar))`.

## Images

Keep the images few: every image goes stale as the UI moves, and a document heavy with them turns each UI change into an illustration chore.

- Illustrate an element, an icon-coded state, or a result with the app's own icon: take the image from the application's resources, save it into the `img/` folder beside the document as PNG 16–24 px high, and place it inline with the text. When the source image cannot be located or read, leave a placeholder and report it.
- Give a screen at most one screenshot — the overview of the whole screen, annotated with the part labels `A`, `B`, `C`… Parts, panels and single elements get no screenshot of their own.
- Leave the screenshots as placeholder image tags for the user to capture and save into `img/`.

## Name the UI elements

Name every control by the established term of the document's language, taken from [`references/TERMS.md`](references/TERMS.md). When a control is missing there, add it to the table rather than coining a term in place.

## Close

When the documentation looks complete, propose to the user a final pass over the code — re-scan for any interactive element or behavior not yet described — and report the gaps before closing.

## Markdown format

[`references/TEMPLATE.md`](references/TEMPLATE.md) carries the Markdown shape — title, TOC markers, anchors, image tags. Beyond what it shows:

- Write the headings and the prose in the language the user asked for, and keep every anchor ASCII — lowercase, hyphenated, diacritics stripped — so links stay stable.
- Keep the table of contents mirroring the heading hierarchy as you add chapters.
