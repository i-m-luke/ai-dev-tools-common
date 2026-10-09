# Notes

## Contents

<!--TOC-->

- [Introduction](#introduction)
- [About the application](#about-the-application)
- [Main window](#main-window)
  - [Toolbar](#toolbar)
  - [Note list and editor](#note-list-and-editor)
- [Exporting notes](#exporting-notes)
- [Deleting a note](#deleting-a-note)

<!--/TOC-->

## Introduction {#introduction}

This document describes the UI of the Notes application.

## About the application {#about-the-application}

Notes keeps short text notes in the browser.

## Main window {#main-window}

**The main window consists of these parts (see the image below):**

- **Toolbar (part A):** commands for the notes (see [Toolbar](#toolbar))
- **Note list and editor (part B):** the notes and the text of the selected one (see [Note list and editor](#note-list-and-editor))

![Main window](img/main-window.png)

### Toolbar {#toolbar}

- **New** — creates an empty note at the top of the list and selects it.
- **Save** — exports all notes to `notes.csv` (see [Exporting notes](#exporting-notes)).
- **Delete** — removes the selected note (see [Deleting a note](#deleting-a-note)).
- **Sort** — sorts the notes alphabetically by title.

### Note list and editor {#note-list-and-editor}

The list shows the first line of each note; clicking a note opens its text in the editor.

## Exporting notes {#exporting-notes}

**Save** downloads every note as one row of `notes.csv` with its id, modification time and text.

## Deleting a note {#deleting-a-note}

**Delete** asks the user to confirm, and only then removes the selected note for good. Nothing is
deleted when no note is selected.
