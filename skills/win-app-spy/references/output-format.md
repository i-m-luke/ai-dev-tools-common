# Output format

The script prints one line of JSON per run. Examples below are real responses from Windows 11
Notepad, pretty-printed; window titles follow the OS language (Czech here).

## Envelope

```json
{ "command": "launch", "data": { … } }
{ "command": "close", "error": { "code": "NOT_LAUNCHED", "message": "Process 4242 was not launched in this session; close closes only apps started by launch." } }
```

- `command` echoes the request's `command`; it is left out when the request had none.
- `data` holds the command's result; `error` replaces it when the command failed.
- Fields that are null or empty (string, array, object) are left out; there is no `ok` field.

## Error object

`{ "code": "…", "message": "…" }` — `message` says what failed and what to do; some codes add
fields (`AMBIGUOUS_MATCH` adds `count` and `candidates`). A command-level error replaces `data`; an
item-level error sits on the item inside `data`, next to its `xpath`, so the other items still
carry their results. `code` is one of (meanings in `SKILL.md` › Error codes):

`INVALID_REQUEST`, `UNKNOWN_COMMAND`, `APP_NOT_FOUND`, `APP_AMBIGUOUS`, `APP_ALREADY_RUNNING`,
`NOT_LAUNCHED`, `CLOSE_FAILED`, `ELEMENT_NOT_FOUND`, `AMBIGUOUS_MATCH`, `ACTION_FAILED`, `TIMEOUT`,
`UNEXPECTED`.

## Exit code

- `0` — no `error` anywhere in the JSON.
- `1` — an `error` at the command level or on any item.
- Any other exit, or no JSON — an environment problem (compilation, NuGet restore, a crash).

## launch

`data.app` describes the launched app — its `pid`, the `title` of its window and the `uia` mode
later requests use for it:

```json
{
  "command": "launch",
  "data": { "app": { "pid": 31652, "title": "Bez názvu – Poznámkový blok", "uia": "UIA3" } }
}
```

The pid is the process that owns the window, which can differ from the process `exe` started
(Windows 11 Notepad hands over from a launcher process). `launch` waits for the window the way
[wait](#wait) does, honouring `timeout` and `poll`.

## attach

`data.app` describes the attached app the same way as `launch` does; `title` is that of a window
matching the request's `title` when it sent one:

```json
{
  "command": "attach",
  "data": { "app": { "pid": 29080, "title": "Bez názvu – Poznámkový blok", "uia": "UIA3" } }
}
```

When several apps match, `APP_AMBIGUOUS`'s message lists each one's pid and title, so the agent can
resend with the right `pid`. Windows 11 Notepad runs all its windows in one process, so a `title`
or `process` matching several Notepad windows still selects that one app.

## close

`data` holds the `pid` of the closed app and how it was `closed`: `gracefully` (its windows were
closed) or `killed` (`"force": true`):

```json
{ "command": "close", "data": { "pid": 25776, "closed": "gracefully" } }
```

## get-state

`data.elements` holds one item per locator. Each item's `xpath` echoes the locator exactly — match
results to locators by it, not by order. A found element's item carries `state` with the keys from
the request's `states`; without `states` the item holds only `xpath`. A failed locator's item
carries `error` instead, and the other items keep their results:

```json
{ "command": "get-state",
  "locators": [ "//MenuItem[@AutomationId='File']", "//MenuBar/MenuItem[1]", "//Button[@AutomationId='SaveBtn']" ],
  "states": [ "name", "enabled" ] }
```

```json
{
  "command": "get-state",
  "data": { "elements": [
    { "xpath": "//MenuItem[@AutomationId='File']", "state": { "name": "Soubor", "enabled": true } },
    { "xpath": "//MenuBar/MenuItem[1]",
      "error": {
        "code": "AMBIGUOUS_MATCH",
        "message": "2 elements matched; send the xpath of the intended candidate or narrow the xpath.",
        "count": 2,
        "candidates": [
          { "xpath": "/Window/Pane[4]/Pane/MenuBar[@AutomationId='MenuBar']/MenuItem[@AutomationId='File']",
            "state": { "name": "Soubor", "enabled": true } },
          { "xpath": "/Window/TitleBar[@AutomationId='TitleBar']/MenuBar[@AutomationId='SystemMenuBar']/MenuItem",
            "state": { "name": "Systém", "enabled": true } } ] } },
    { "xpath": "//Button[@AutomationId='SaveBtn']",
      "error": { "code": "ELEMENT_NOT_FOUND", "message": "No element matched." } } ] }
}
```

- `ELEMENT_NOT_FOUND` — the locator matched nothing.
- `AMBIGUOUS_MATCH` — the locator matched several elements; the error adds `count` (all matches)
  and `candidates`: the first 5 matches in document order as `{ xpath, state }`, each with the
  concrete xpath of that one element (see `references/xpath.md`).
- `INVALID_REQUEST` on an item — the xpath is outside the supported subset.

A locator object with `"all": true` gets `matches` instead of `state`: every match in document
order as `{ xpath, state }` with its concrete xpath — never `AMBIGUOUS_MATCH`; with no match the
item holds only `xpath`:

```json
{ "command": "get-state", "locators": [ { "xpath": "//MenuBar[@AutomationId='MenuBar']/MenuItem", "all": true } ], "states": [ "name" ] }
```

```json
{ "command": "get-state", "data": { "elements": [
  { "xpath": "//MenuBar[@AutomationId='MenuBar']/MenuItem", "matches": [
    { "xpath": "/Window/Pane[4]/Pane/MenuBar[@AutomationId='MenuBar']/MenuItem[@AutomationId='File']", "state": { "name": "Soubor" } },
    { "xpath": "/Window/Pane[4]/Pane/MenuBar[@AutomationId='MenuBar']/MenuItem[@AutomationId='Edit']", "state": { "name": "Upravit" } },
    { "xpath": "/Window/Pane[4]/Pane/MenuBar[@AutomationId='MenuBar']/MenuItem[@AutomationId='View']", "state": { "name": "Zobrazit" } } ] } ] } }
```

### State keys

`states` takes any of these keys; a key the element does not support, or whose value is empty, is
left out of its `state`.

| Key | Value |
|---|---|
| `name` | The element's name — its label or window title, in the OS language. |
| `automationId` | The element's AutomationId. |
| `controlType` | The control type, as used in xpaths (`Button`, `MenuItem`, …). |
| `className` | The UI framework's class name of the element. |
| `enabled` | `true` when the element accepts input. |
| `offscreen` | `true` when the element is not visible on screen (hidden, scrolled away, collapsed). |
| `bounds` | `{ x, y, width, height }` in screen pixels; left out for an element without a position. |
| `value` | The text of an element with a value, e.g. an edit box or Notepad's text editor. |
| `toggle` | `on`, `off` or `indeterminate` for a check box or toggle button. |
| `selected` | `true` when a selectable item (tab, list item) is selected. |
| `expanded` | `true` when an expandable element (menu, tree node, combo box) is expanded, `false` when collapsed. |

```json
{ "command": "get-state",
  "locators": [ "//MenuItem[@AutomationId='File']", "//TabItem" ],
  "states": [ "controlType", "className", "enabled", "offscreen", "bounds", "selected", "expanded" ] }
```

```json
{
  "command": "get-state",
  "data": { "elements": [
    { "xpath": "//MenuItem[@AutomationId='File']",
      "state": { "controlType": "MenuItem", "className": "Microsoft.UI.Xaml.Controls.MenuBarItem", "enabled": true,
                 "offscreen": false, "bounds": { "x": 887, "y": 201, "width": 65, "height": 32 }, "expanded": false } },
    { "xpath": "//TabItem",
      "state": { "controlType": "TabItem", "className": "ListViewItem", "enabled": true,
                 "offscreen": false, "bounds": { "x": 927, "y": 169, "width": 111, "height": 32 }, "selected": true } } ] }
}
```

## dump-tree

`data.nodes` holds the app's top-level windows — or the one element `root` (an xpath) matches —
with their descendants nested in `children`, listed level by level. Each node carries its concrete
xpath (send it to other commands as is) and `state` with the keys from `states`. Parameters:
`depth` (levels below the app or `root`, default 4), `maxNodes` (default 300), `includeOffscreen`
(default false; `root` itself is always listed), `states`. When the dump is cut, `data.truncated`
is true and every node whose children were not all listed carries `childCount` (on `data` itself
when windows were left out):

```json
{ "command": "dump-tree", "depth": 2, "maxNodes": 20, "states": [ "name" ] }
```

```json
{ "command": "dump-tree", "data": { "truncated": true, "nodes": [
  { "xpath": "/Window", "state": { "name": "Bez názvu – Poznámkový blok" }, "children": [
    { "xpath": "/Window/Pane[1]", "childCount": 1 },
    { "xpath": "/Window/Pane[2]", "childCount": 1 },
    { "xpath": "/Window/Pane[3]", "childCount": 1 },
    { "xpath": "/Window/Pane[4]", "childCount": 1 },
    { "xpath": "/Window/Pane[5]", "childCount": 1 } ] } ] } }
```

`root` answers `ELEMENT_NOT_FOUND` / `AMBIGUOUS_MATCH` like a get-state locator, but as the
command's `error`.

## act

Performs `action` on the one element `locator` matches (an xpath string), then returns `xpath`
and, with `states`, the element's `state` read after the action:

```json
{ "command": "act", "locator": "//MenuItem[@AutomationId='View']", "action": "expand", "states": [ "expanded" ] }
```

```json
{ "command": "act", "data": { "xpath": "//MenuItem[@AutomationId='View']", "state": { "expanded": true } } }
```

| `action` | Extra field | Does |
|---|---|---|
| `click`, `doubleClick`, `rightClick` | | moves the mouse to the element and clicks |
| `focus` | | gives the element keyboard focus |
| `type` | `text` | focuses the element and types the text |
| `setValue` | `value` | sets the value (Value pattern); `""` clears it |
| `invoke`, `toggle`, `select`, `expand`, `collapse` | | uses the element's Invoke, Toggle, SelectionItem or ExpandCollapse pattern |
| `key` | `keys` | focuses the element and presses the keys together, e.g. `Ctrl+A`, `Enter`, `Escape`, `F5` |

Errors: `ELEMENT_NOT_FOUND` / `AMBIGUOUS_MATCH` (nothing is done), `ACTION_FAILED` (the element
lacks the pattern or the action threw), `INVALID_REQUEST` (unknown `action` or key, missing field).

## wait

Polls `locator` (an xpath string) with a fresh look at the UI every `poll` ms (default 250, at
least 1) until `condition` holds, for up to `timeout` ms (default 10000):

| `condition` | Holds when |
|---|---|
| `exists` (default) | the locator matches one element |
| `gone` | the locator matches nothing |
| `enabled` | the one match is enabled |
| `visible` | the one match is not offscreen |

```json
{ "command": "wait", "locator": "//MenuItem[@AutomationId='File']", "condition": "enabled", "timeout": 5000 }
```

```json
{ "command": "wait", "data": { "xpath": "//MenuItem[@AutomationId='File']", "condition": "enabled" } }
```

When the condition does not hold in time the error is `TIMEOUT`:

```json
{ "command": "wait", "error": { "code": "TIMEOUT",
  "message": "'//Window[@AutomationId='PrivacyTeachingTip']' did not become visible within 1000 ms (polled every 250 ms)." } }
```

A locator matching several elements answers `AMBIGUOUS_MATCH` at once.

## screenshot

Captures a window of the app as a PNG in the working folder. With `xpath` it captures just the one
element the xpath matches; without it, the app's front window:

```json
{ "command": "screenshot", "xpath": "//MenuItem[@AutomationId='File']" }
```

`data.path` is the PNG's full path; `data.window` is the window the image comes from — its native
`handle` and `title`; `data.element` echoes the request's `xpath`, and is left out for a whole
window:

```json
{
  "command": "screenshot",
  "data": {
    "path": "C:\\Users\\me\\AppData\\Local\\Temp\\win-app-spy\\20261016-103311\\screenshot-20261016-103316-005.png",
    "window": { "handle": 4850202, "title": "Bez názvu – Poznámkový blok" },
    "element": "//MenuItem[@AutomationId='File']"
  }
}
```

- The image comes from the window's own rendering: a window behind others comes out whole, and
  nothing is brought to the front. To capture another top-level window, send its xpath (e.g.
  `//Window[@AutomationId='…']`).
- `ELEMENT_NOT_FOUND`, `AMBIGUOUS_MATCH` (with `count` and `candidates`) and `INVALID_REQUEST` for
  the xpath come as in `get-state`, but at the command level; no file is written.
- A minimized window, or an element with no visible area in its window, gives `UNEXPECTED` with a
  message saying so.
