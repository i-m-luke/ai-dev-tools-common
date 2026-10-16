# FlaUI basics for ad hoc scripts

When no command does what the task needs, write an ad hoc script on the shared core. The core
connects to the app, keeps the session and prints the standard envelope; the script adds only the
FlaUI calls the task needs. FlaUI's own documentation: <https://github.com/FlaUI/FlaUI> and its
wiki <https://github.com/FlaUI/FlaUI/wiki>.

## Load the core

Save the script as `<name>.csx` in the working folder, beside `core.csx`, and start it with
`#load "core.csx"`. The core brings FlaUI 5.0.0 and works out the working folder from its own path,
so the script shares `session.json` — the active app and the launched apps — with the requests.
Run it from the working folder with `dotnet script <name>.csx -- req.json`; the request file is
optional, and its first run compiles the script. Read the result by the playbook of step 3.

Each `.csx` file lists its own `using`s; they do not carry over through `#load`. Under
`#nullable enable`, dotnet-script fails the compilation on nullable warnings; mark a value you know
is set with `!`.

## The core's API

- `Envelope.Run(command, () => data)` — runs the body, prints the envelope with its `data` (or the
  `error` it threw) and returns the exit code; make it the script's `return`.
- `Request.Load(path)` reads a request file; `String`, `RequiredString`, `Int`, `Bool` and
  `Object(name)` read its fields and answer a wrong type with `INVALID_REQUEST`.
- `Apps.Target(request, Session.Load())` — the `pid` and `uia` mode the request targets: its `app`,
  otherwise the active app.
- `Apps.CreateAutomation(uia)` — the UIA automation to search with; create every automation
  through it, since it loads what FlaUI needs under dotnet-script. Dispose it with `using`.
- `Apps.TopLevelWindows(automation, pids)` — the app's top-level windows, the roots to search
  from; `Apps.Describe(window, app)` gives a window's `{ pid, title, uia }`.
- `Poll.Until(probe, timeoutMs)` — repeats the probe every 250 ms until it returns non-null or the
  timeout passes; use it to wait for UI to appear. `Poll.Until(probe, Poll.Options.Read(request))`
  takes the request's `timeout` and `poll` the way the `wait` command does.
- `throw new SpyError(ErrorCodes.X, message)` fails the whole run; `Envelope.Error(code, message)`
  is the `error` to put on a single item inside `data`, `Envelope.Error(exception)` the one for a
  caught exception.
- `Locator.Root(automation, pid)` — the root xpaths start from, over all the app's top-level
  windows; `Locator.Single(root, xpath)` returns the one matching node (or throws
  `ELEMENT_NOT_FOUND` / `AMBIGUOUS_MATCH` like `get-state`), `Locator.Resolve(root, xpath)` all of
  them. A node holds the FlaUI `Element` and its concrete `XPath`; `ElementState.Read(element,
  states)` gives the `state` object `get-state` returns.

## FlaUI essentials

- **Find** elements under a window: `FindFirstDescendant(cf => cf.ByControlType(ControlType.Button))`,
  `FindAllDescendants(...)`, `FindAllChildren()`; combine conditions with `.And(...)`. Window titles
  and element names follow the OS language, so match on `ByAutomationId` or the control type.
- **Read** properties through `element.Properties.X.ValueOrDefault` (`Name`, `AutomationId`,
  `ClassName`, `ControlType`, `IsEnabled`, `BoundingRectangle`); the direct getters such as
  `element.AutomationId` throw when the app does not support the property.
- **Patterns** drive controls: `element.Patterns.Value.PatternOrDefault?.SetValue("text")`,
  `Patterns.Invoke`, `Patterns.Toggle`, `Patterns.SelectionItem`, `Patterns.ExpandCollapse`; a
  pattern the element lacks comes back `null`.
- **Act** with `element.AsButton().Invoke()`, `element.Click()` or `element.Focus()`, and type with
  `Keyboard.Type("text")` (`FlaUI.Core.Input`) — input goes to the foreground window, so call
  `window.SetForeground()` first.

## Sample script

Lists the buttons in every window of the active app, or of the app the request names:

```csharp
#nullable enable
#load "core.csx"

using System.Text.Json.Nodes;
using FlaUI.Core.Definitions;

return Envelope.Run("list-buttons", () =>
{
    var request = Args.Count > 0 ? Request.Load(Path.GetFullPath(Args[0])) : new Request(new JsonObject());
    var target = Apps.Target(request, Session.Load());
    using var automation = Apps.CreateAutomation(target.Uia);
    var windows = new JsonArray();
    foreach (var window in Apps.TopLevelWindows(automation, new HashSet<int> { target.Pid }))
    {
        var buttons = new JsonArray();
        foreach (var button in window.FindAllDescendants(cf => cf.ByControlType(ControlType.Button)))
        {
            buttons.Add(new JsonObject
            {
                ["name"] = button.Properties.Name.ValueOrDefault,
                ["automationId"] = button.Properties.AutomationId.ValueOrDefault,
            });
        }

        windows.Add(new JsonObject { ["title"] = window.Properties.Name.ValueOrDefault, ["buttons"] = buttons });
    }

    return new JsonObject { ["windows"] = windows };
});
```

Run against Windows 11 Notepad after `launch` (abridged):

```json
{
  "command": "list-buttons",
  "data": {
    "windows": [
      {
        "title": "Bez názvu – Poznámkový blok",
        "buttons": [
          { "name": "Přidat novou kartu", "automationId": "AddButton" },
          …
          { "name": "Zavřít", "automationId": "Close" }
        ]
      }
    ]
  }
}
```
