# XPath locators

A locator is an XPath string that addresses elements of the target app's UI. The script supports
the subset below; anything else answers `INVALID_REQUEST` on that locator's item, with the
character where parsing failed.

## Grammar

```text
xpath      = step { step }
step       = "/" Type { predicate }        children of the current nodes
           | "//" Type { predicate }       descendants of the current nodes, at any depth
predicate  = "[" n "]"                     the n-th (from 1) of the siblings left so far
           | "[" condition "]"
condition  = term { "or" term }
term       = primary { "and" primary }
primary    = "@" Attribute "=" literal      exact, case-sensitive match
           | "contains(" "@" Attribute "," literal ")"   case-sensitive substring
           | "(" condition ")"
Attribute  = AutomationId | Name | ClassName
literal    = 'text' | "text"
```

- `Type` is a UIA control type, case-sensitive: `Window`, `Pane`, `Button`, `Edit`, `Document`,
  `MenuBar`, `MenuItem`, `Tab`, `TabItem`, `CheckBox`, `TitleBar`, …
- `[n]` counts among siblings of the same type: in `//MenuBar/MenuItem[1]` it is the first
  `MenuItem` child of a `MenuBar`, whatever other children precede it. Predicates apply left to
  right, so `//Button[@Name='OK'][2]` is the second `OK` button among its siblings.
- Whitespace is allowed inside `[ ]`.
- `and` binds tighter than `or`; group with `( )`, e.g.
  `//MenuItem[(@AutomationId='File' or @AutomationId='Edit') and contains(@ClassName, 'Item')]`.

## Every match

A locator object `{ "xpath": "...", "all": true }` returns all its matches as `matches` instead of
answering `AMBIGUOUS_MATCH`; each match carries its concrete xpath (see below), ready to send back.
String and object locators mix in one `locators` list.

## The root

An xpath starts at a virtual root whose children are all top-level windows of the app's process.
`/Window` selects the app's top-level windows; `//Button` searches every window at once.

## Dialogs

A dialog is a `Window` — top-level, or nested inside the main window (Notepad nests its teaching
tips this way). `//Window[...]` reaches both, so prefer `//` over `/` for dialogs. Identify a
dialog by `@AutomationId`, which stays the same in every OS language; `@Name` holds its localized
title and is a fallback:

```json
{ "command": "get-state", "locators": [ "//Window[@AutomationId='PrivacyTeachingTip']" ], "states": [ "controlType", "className", "offscreen" ] }
```

```json
{ "command": "get-state", "data": { "elements": [
  { "xpath": "//Window[@AutomationId='PrivacyTeachingTip']",
    "state": { "controlType": "Window", "className": "Microsoft.UI.Xaml.Controls.TeachingTip", "offscreen": true } } ] } }
```

## Concrete xpaths

When an xpath matches several elements, `AMBIGUOUS_MATCH` lists candidates with a concrete xpath
each: one `/` step per level from the root, every step narrowed to exactly that element — by
`@AutomationId` when it is unique among same-type siblings, otherwise by position, and bare when
the element is the only one of its type:

```text
/Window/Pane[4]/Pane/MenuBar[@AutomationId='MenuBar']/MenuItem[@AutomationId='File']
```

Send a candidate's xpath back to address that one element.

## Lifetime

An xpath is valid only for the UI state it was written against: a positional step such as
`Pane[4]` points elsewhere once the app adds, removes or reorders elements. After the UI changes,
resolve the element again — prefer locators built on `@AutomationId`, which survive such changes.
