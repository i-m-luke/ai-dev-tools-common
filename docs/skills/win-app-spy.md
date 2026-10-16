# win-app-spy

[`win-app-spy`](../../skills/win-app-spy/SKILL.md) lets an agent inspect and drive the UI of any
Windows desktop app through one script and a JSON request/response contract; the design lives in
[issue #1](https://github.com/i-m-luke/ai-dev-tools-common/issues/1).

## Prerequisites

The skill runs on the .NET SDK and the global tool `dotnet-script`
(`dotnet tool install -g dotnet-script`); its preflight script checks both and prints how to install
whatever is missing. Without `dotnet-script`, the script tests that need it are skipped.

## Working folder

Each conversation gets its own folder under `%TEMP%\win-app-spy\`, kept after the task so the user
can review what the agent did. It replaces the repo's `.artifacts/` convention on purpose: the skill
runs in any repository, or none.

## Verifying changes

Run every command and example you touch against Windows 11 Notepad started through the skill's
`launch`, never against Notepad windows the user opened. Delete any text typed during the check and
close the instance through `close`, since Notepad restores unsaved tabs. `launch` can bring up a
tab Notepad restored from the user's session; open a new tab before typing, and close it once
emptied. The script tests leave out these Notepad runs: parallel runs would share one desktop and
one Notepad process. Tests that need a window use their own fixture app instead, which never takes
focus, and skip in CI, which has no desktop; get-state's fixture
(`script-tests/win-app-spy/fixture-app.ps1`) stays open only while its tests hold the shared GUI
lock.

## FlaUI and the WindowsDesktop runtime

The core pins FlaUI 5.0.0 (`FlaUI.UIA3`, `FlaUI.UIA2`), the newest stable release; an exact version
also lets dotnet-script reuse its compiled script between runs. dotnet-script compiles for plain
`net10.0`, so FlaUI's Windows Desktop dependencies (`Accessibility` for UIA3; `UIAutomationClient`
and the real `WindowsBase` for UIA2) are loaded from the installed `Microsoft.WindowsDesktop.App`
into a load context of their own; UIA2's automation is created there by reflection. Code creates
automations only through `Apps.CreateAutomation`, which sets this up.

`screenshot.csx` pins `System.Drawing.Common` 8.0.10, the version FlaUI 5.0.0 itself depends on, to
write PNGs; plain `net10.0` lacks it. It captures through the window's own rendering
(`PrintWindow`), so a window behind others comes out whole and nothing takes focus.

## Adding a command

Each command is a `<command>.csx` file with a `JsonNode? Run(Request)` handler that returns the
response's `data` and throws `SpyError` for a command-level error. `win-app-spy.csx` `#load`s it and
lists it in its dispatch table, both kept alphabetical. Shared pieces — the envelope, request
fields, session state, app connection, polling and locators — live in `core.csx` and the files it
loads, which ad hoc scripts load too.
