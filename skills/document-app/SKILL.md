---
name: document-app
description: Use ONLY when the literal text "/document-app" appears in the request or instructions — never otherwise, whatever the task.
---

Document the application's UI, functionality and purpose **based on the code**, as a new document or as edits to an existing one.

## Initialization

### 1. Settle the document

Settle which document you write and its language by this playbook:

- The request names an existing document — edit it, in its language.
- The request names a new document — fill in `assets/TEMPLATE.md` as that document, in the language the user asked for; ask for the language first when the user named none.
- `*` — ask the user for the document's path, then act by this playbook.

Done when the document exists and you know its language.

### 2. Find the UI entry point

Find the app's UI entry point — app startup, main window, or root page — and act by this playbook:

- One top-level window or page — read its layout definition.
- Several top-level windows — ask the user which one is the main one, then read its layout definition.
- No graphical UI (a CLI tool, service, or library) — tell the user this skill documents screens and ask whether to document its entry points and commands instead; follow the answer, or stop when the user declines.

Done when you have read the layout definition of the screen the walk starts at.

## Steps

### 1. Walk the UI top-down

Walk the app **top-down** from the entry point's screen: finish each level before the next — the screen, then its sections, then their smaller components. When editing an existing document, walk only the screens and tasks the request names.

- For each container, identify all its child regions before descending into any of them.
- For each element, follow the code wired to it — its handler, command, or binding target — and note what that code actually does. A label is a claim to verify; the code that runs is the evidence.
- When the wired code is missing or cannot be located, mark the element **[Unknown behavior — unable to determine based on code]**.

Done when every interactive element on the walked screens has its behavior read from the code or carries the mark.

### 2. Write the chapters

Write the headings and prose in the document's language, in this sequence of chapters, as `assets/TEMPLATE.md` lays them out:

- **Introduction** — what this document covers.
- **About the application** — what the app is for, who uses it, and how input reaches it (files the user opens, data pushed from other systems, commands the user issues).
- **Screen chapters** — the UI and controls of each screen, top-down.
- **Application settings** — placed before behavior, so the behavior chapters can refer to it.
- **Behavior chapters** — each named after the user task it serves (`Importing a file`, `Running a job`).

A screen chapter states what an element is and what one operation of it does; a behavior chapter carries the flows, states, conditions and rules that span more than one element — put a borderline case in behavior.

- **Screens** — open with a short intro — "The main window consists of these parts:" — and break a complex layout into logical sections. Label each part `A`, `B`, `C`… keyed to the screen's screenshot, and list them as: **bold part name (part A):** its purpose, then a link to the section that covers it in depth.
- **Elements** — describe each element (button, tree, menu item…) by its purpose, function and behavior, from the code wired to it.
- **Settings** — document the global settings and preferences as a chapter of options: give each option its effect, its allowed values, the condition under which it is available, and when and how a change is stored. Options that belong to a single screen or task stay where they live.

Read `references/TERMS.md` when you name a UI control. Take the control's term in the document's language from it; when the control is missing there, add it as a new row.

Done when every screen, setting and user task the walk found has its chapter.

### 3. Add the images

Keep the images few: each one goes stale as the UI moves.

- **Screenshots** — give each screen one overview screenshot, annotated with the part labels `A`, `B`, `C`…, as a placeholder image tag for the user to capture into `img/`. Parts, panels and single elements are shown by that overview and by their icons.
- **Icons** — illustrate an element, an icon-coded state, or a result with the app's own icon, placed inline with the text. For each icon file in the application's resources, run `pwsh -NoProfile -File <this skill's folder>/scripts/convert-icon.ps1 -SourcePath "<icon file>" -DestinationPath "<document folder>/img/<name>.png"`. Act on the script's exit code by this playbook:
  - `0` — place the PNG inline.
  - `2` or `3` — leave a placeholder image tag and note the icon for the report.
  - `*` — show the user the script's stderr, or the error when it failed to start, and stop.

  An icon with no file of its own — a font glyph or a vector drawn in code — gets a placeholder image tag, noted for the report.

Done when every screenshot and icon the chapters call for is placed or noted as a placeholder.

### 4. Cross-reference

A cross-reference keeps one meaning in one chapter instead of retelling it in another. Link on the first mention within a chapter and leave the later mentions plain, in these cases:

- An element whose full behavior lives in a behavior chapter links to it, and that chapter links back to the element that starts the task.
- A setting that gates an element, a task, or a rule is linked from wherever that condition is stated.
- Any other chapter you name in the text is linked where you name it: `(see [Main menu bar](#main-menu-bar))`.

Link a heading by the anchor step 5 gives it — its text in ASCII, lowercase and hyphenated; step 5 also reports every link that misses. Done when every case above in every chapter you wrote carries its link.

### 5. Update the table of contents

Run `pwsh -NoProfile -File <this skill's folder>/scripts/update-toc.ps1 -Path "<the document>"`. Act on the script's exit code by this playbook:

- `0` — repoint each link in `brokenLinks` at the anchor of the heading it means. Go back to step 5 while `brokenLinks` is not empty — at most 3 times, or until a round leaves the result unchanged; then note the remaining broken links for the report.
- `3` — add the `<!--TOC-->` and `<!--/TOC-->` markers under the contents heading as `assets/TEMPLATE.md` shows them. Go back to step 5 while the script exits `3` — at most once; then show the user the script's stderr and stop.
- `*` — show the user the script's stderr, or the error when it failed to start, and stop.

Done when the script exits `0` with no broken links, or the remaining ones are noted for the report.

### 6. Offer a final pass

Ask the user whether to run a final pass over the code, and act by this playbook:

- Yes — re-scan the code for interactive elements and behavior the document leaves out. Go back to step 1 for what it finds while it finds any — at most 2 times, or until a round leaves the result unchanged; then go on to step 7. In a repeated round, run the re-scan without asking again.
- `*` — go on to step 7.

Done when the user has answered and any pass they accepted is finished.

### 7. Report

Tell the user what changed, linking the document and every file you created or changed — images in `img/`, and `references/TERMS.md` when you added a row. List the gaps: every element marked **[Unknown behavior — unable to determine based on code]**, every screenshot to capture, every icon left as a placeholder, and every remaining broken link. Done when the user has the report.

## Scripts

Run a script with `pwsh`, or with `powershell` in place of `pwsh` when pwsh is missing. Print a script's help with `pwsh -NoProfile -Command "Get-Help '<this skill's folder>/scripts/<script>.ps1' -Full"` and read it before you run the script for the first time. Read the script's source only when the help leaves out what you need, and then tell the user which part the help left out.

The exit code alone decides whether a script succeeded:

- On `0`, when the help says the script returns a result, take the compact JSON after `::result::` on the one stdout line that starts with it; every other stdout line is log. When that line is missing or appears more than once, tell the user the script broke its contract and stop.
- On any other exit code, ignore stdout; the error is on stderr.
