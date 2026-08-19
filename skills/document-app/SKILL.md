---
name: document-app
description: Document an application's UI, functionality and purpose from the code. Use when writing app UI documentation, when revising it after a code change, or when another skill needs these conventions.
---

Document the application's UI, functionality and purpose **based on the code**.

Describe the app **top-down**: start at the highest-level screen (main window, page) and only then descend to sections, and then to smaller components.

Derive every description from the code, so the document reports what the app does, not what its labels suggest:

- Start at the UI entry point — app startup, main window, or root page — and read its layout definition. If the app has more than one top-level window, ask the user which one is the main one and start there.
- For each container, identify all its child regions before descending into any of them.
- For each element, follow the code wired to it — its handler, command, or binding target — and state what that code actually does.
- Account for every interactive element: a control whose behavior you have not read in the code is a gap to resolve, not a blank to fill from its label. When the wired code is missing or cannot be located, mark it in the document as **[Unknown behavior — unable to determine based on code]** rather than inferring behavior from the label.

Lay the document out as this sequence of chapters, and scaffold a document from [`TEMPLATE.md`](TEMPLATE.md):

- **Introduction** — what this document covers.
- **About the application** — what the app is for and how work reaches it.
- **Screen chapters** — the UI and controls of each screen, top-down.
- **Application settings** — placed here, before behavior, so the behavior chapters can refer to it.
- **Behavior chapters** — named after the user task they serve (`Importing a file`, `Running a job`), never after the screen the task happens on.

A screen chapter states what an element is and what one operation of it does; a behavior chapter carries the flows, states, conditions and rules that span more than one element — put a borderline case in behavior. Wire the two together in both directions instead of repeating the behavior: the element links to the behavior chapter, and the behavior chapter links back to the element that starts the task.

Document the screens this way: give the screen a short intro — "The main window consists of these parts:" — then break a complex layout into logical sections. Label each part `A`, `B`, `C`… keyed to an annotated screenshot, and list them as: **bold part name (part A):** its purpose, then a link to the section that covers it in depth.

Document the smaller UI components this way: describe each element (button, tree, menu item…) by its purpose, function and behavior, based on the code attached to it.

Document the application's global settings and preferences as a chapter of options rather than as a screen — no layout, no parts, no screenshot. Give each option its effect, its allowed values, the condition under which it is available, and when and how a change is stored. Options that belong to a single screen or task stay documented where they live.

When the documentation looks complete, propose to the user a final pass over the code — re-scan for any interactive element or behavior not yet described — and report the gaps before closing.

[`TEMPLATE.md`](TEMPLATE.md) carries the Markdown shape — title, TOC markers, anchors, image tags. Beyond what it shows:

- Write the headings and the prose in the language the user asked for, and keep every anchor ASCII — lowercase, hyphenated, diacritics stripped — so links stay stable.
- Keep the table of contents mirroring the heading hierarchy as you add chapters.
- Cross-reference another chapter inline where you name it: `(see [Main menu bar](#main-menu-bar))`.
- Leave the image tags as placeholders for the user to capture and save into `img/`.
