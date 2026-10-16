# Troubleshooting

Recover from environment problems; each section names the symptom first.

## No JSON and a non-zero exit

The script did not get to run. Read its output:

- `error CS…` — a compilation error, usually in an ad hoc script; fix the line it names. Under
  `#nullable enable` nullable warnings fail the build too.
- `NU1100` / `Unable to resolve` / `NU1301` — NuGet restore failed; see [NuGet](#nuget).
- Anything else — show the user the output and end the skill.

## NuGet

The first run restores the FlaUI packages from nuget.org.

- `NU1100` with "package source mapping": a `NuGet.Config` in a parent folder maps packages to
  other feeds. The working folder under `%TEMP%` avoids this; when it still happens, put a
  `NuGet.Config` holding `<packageSources><clear /><add key="nuget.org" value="https://api.nuget.org/v3/index.json" /></packageSources>`
  beside the scripts.
- `NU1301` (no connection): the machine is offline or behind a proxy; ask the user to restore
  access to nuget.org, then retry.

## dotnet-script missing

`dotnet script` fails with "could not execute because the specified command or file was not found",
or preflight exits 1: run `scripts/preflight.ps1` as initialization step 1 does and follow the
installation instructions it prints
(`dotnet tool install -g dotnet-script`; open a new shell so `PATH` picks it up).

## Empty tree

`dump-tree` lists no nodes, or every locator answers `ELEMENT_NOT_FOUND`:

- The app's window may not be ready yet — `wait` for an element you expect, then retry.
- The app may expose its UI only to the other automation mode — resend with `"uia": "UIA2"` (or
  `"UIA3"`); see [UIA2 or UIA3](#uia2-or-uia3).
- Offscreen elements are left out of `dump-tree` by default — send `"includeOffscreen": true`.
- The app may run as administrator — see [Apps running as administrator](#apps-running-as-administrator).

## UIA2 or UIA3

UIA3 (default) suits WPF, WinUI, UWP and modern Win32 apps; UIA2 sometimes sees more of old
WinForms or Win32 apps, and less of WPF/WinUI. When a tree looks empty, flat or wrong, compare a
`dump-tree` in both modes and keep the better one; `launch` and `attach` remember the mode for the
active app.

## Apps running as administrator

Windows blocks UI Automation from a normal process into an elevated one: the app's windows appear
with no children, `act` fails with `ACTION_FAILED`, or `launch` reports `TIMEOUT`. Ask the user
to start the app without elevation, or to run the agent's shell as administrator.
