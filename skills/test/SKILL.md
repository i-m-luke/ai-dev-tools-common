---
name: test
description: Document an application's UI top-down, screen by screen based on the code.
disable-model-invocation: true
---

Document the application's UI, functionality and purpose **based on the code**.

Describe the app **top-down**: start at the highest-level screen (main window, page) and only then descend to sections, and then to smaller components.

Derive every description from the code, so the document reports what the app does, not what its labels suggest:

- Start at the UI entry point — app startup, main window, or root page — and read its layout definition.
- Walk the layout top-down; for each container identify its child regions before descending into them.
- For each element, follow the code wired to it — its handler, command, or binding target — and state what that code actually does.
- Account for every interactive element: a control whose behavior you have not read in the code is a gap to resolve, not a blank to fill from its label.

Document the screens this way: give the screen a short intro — "The main window consists of these parts:" — then break a complex layout into logical sections. Label each part `A`, `B`, `C`… keyed to an annotated screenshot, and list them as: **bold part name (part A):** its purpose, then a link to the section that covers it in depth.

Document the smaller UI components this way: describe each element (button, tree, menu item…) by its purpose, function and behavior, based on the code attached to it.

Structure the Markdown file this way:

- One `#` H1 title at the top.
- A table of contents between `<!--TOC-->` and `<!--/TOC-->`, as nested bullets mirroring the heading hierarchy, each a link `[Title](#anchor)`.
- An explicit ASCII anchor on every heading: `## Main window overview {#main-window-overview}` — lowercase, hyphenated, diacritics stripped, so links stay stable.
- Cross-reference another chapter inline where you name it: `(see [Main menu bar](#main-menu-bar))`.
- Put screenshots in an `Img/` folder beside the document and embed them: `![App overview](Img/app-overview.png)`.
