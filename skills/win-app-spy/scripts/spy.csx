// win-app-spy main script; its help is the Help string below: dotnet script spy.csx -- --help
// The request's `command` selects a handler from the table below; each command lives in its own file.
#nullable enable
#load "core.csx"
#load "act.csx"
#load "attach.csx"
#load "close.csx"
#load "dump-tree.csx"
#load "get-state.csx"
#load "launch.csx"
#load "screenshot.csx"
#load "wait.csx"

const string Help = """
    spy.csx — inspects and drives the UI of a Windows desktop app through UI Automation.

    Usage
      dotnet script <scripts folder>/spy.csx -- --new-working-folder
      dotnet script <scripts folder>/spy.csx -- --request-path <file>
      dotnet script <scripts folder>/spy.csx -- --help [<command>]

    Input
      --new-working-folder   Creates a working folder %TEMP%\win-app-spy\<yyyyMMdd-HHmmss> for one
                             conversation's requests, session state and screenshots.
      --request-path <file>  Runs the request in <file>: a JSON object whose `command` selects what
                             to do. The file's folder is the working folder: session.json there keeps
                             the active app and the apps launched from it between runs.
      --help [<command>]     Prints this help, or a command's request fields and result.

      Every request may also send:
        app  The app to target instead of the active one, by exactly one of { "pid": 1234 },
             { "process": "notepad" } (the exe name) or { "title": "…" } (part of a window title,
             any case).
        uia  "UIA3" (default) or "UIA2", the UI Automation mode; launch and attach remember it for
             the app.

    Result
      --new-working-folder  ::result::{"workingFolder":"<path>"}
      --request-path        ::result::{"command":"<command>","data":{…}} — the data of each command
                            is in its help. Fields that are null or empty are left out. An item
                            inside data (e.g. a get-state locator) may carry an `error` object
                            instead of its result; the other items keep theirs.
      --help                None.

    Exit codes
      0  Success; the result is on stdout.
      20 The command failed with an error from the list below; the error is on stderr.

    Stderr
      The error as one line of JSON, { "code": "…", "message": "…" }: the message says what failed
      and what to do; AMBIGUOUS_MATCH adds `count` and `candidates`. An unexpected failure (exit 1)
      writes its details the same way, with the code UNEXPECTED.

    Error codes
      INVALID_REQUEST      The request file is missing or not a JSON object, or a field is missing
                           or of the wrong type; on an item, its xpath is outside the supported
                           subset.
      UNKNOWN_COMMAND      No such command; the message lists the known ones.
      APP_NOT_FOUND        The exe cannot be started, no process has the pid, no app with a window
                           matches `app`, or there is no active app.
      APP_AMBIGUOUS        Several apps match `app`'s process or title; the message lists their
                           pids and titles.
      APP_ALREADY_RUNNING  launch saw the window open in an instance that was already running and
                           was not launched from this working folder.
      NOT_LAUNCHED         close targets an app not launched from this working folder.
      CLOSE_FAILED         The app has no window to close.
      ELEMENT_NOT_FOUND    A locator matched no element.
      AMBIGUOUS_MATCH      A locator matched several elements; `count` gives how many,
                           `candidates` the concrete xpaths and states of the first 5.
      ACTION_FAILED        act could not perform the action, e.g. the element lacks its pattern;
                           the message suggests an alternative.
      TIMEOUT              launch saw no window in time (it stopped the process it started), close
                           saw the app still running, or wait's condition did not hold in time.
      UNEXPECTED           Any other failure; the message holds the details.

    States
      Commands that read elements take `states`, a list of these keys; a key the element does not
      support, or whose value is empty, is left out of its `state`.
      name          The element's name: its label or window title, in the OS language.
      automationId  The element's AutomationId.
      controlType   The control type, as used in xpaths (Button, MenuItem, …).
      className     The UI framework's class name of the element.
      enabled       true when the element accepts input.
      offscreen     true when the element is not visible on screen (hidden, scrolled away,
                    collapsed).
      bounds        { x, y, width, height } in screen pixels; left out for an element without a
                    position.
      value         The text of an element with a value, e.g. an edit box or Notepad's editor.
      toggle        on, off or indeterminate for a check box or toggle button.
      selected      true when a selectable item (tab, list item) is selected.
      expanded      true when an expandable element (menu, tree node, combo box) is expanded,
                    false when collapsed.
    """;

// To add a command: write <command>.csx with a handler `JsonNode? Run(Request)` and its `Help`,
// #load it above and add its entry here, keeping both lists alphabetical.
var commands = new Dictionary<string, Command>
{
    ["act"] = new(ActCommand.Run, ActCommand.Help),
    ["attach"] = new(AttachCommand.Run, AttachCommand.Help),
    ["close"] = new(CloseCommand.Run, CloseCommand.Help),
    ["dump-tree"] = new(DumpTreeCommand.Run, DumpTreeCommand.Help),
    ["get-state"] = new(GetStateCommand.Run, GetStateCommand.Help),
    ["launch"] = new(LaunchCommand.Run, LaunchCommand.Help),
    ["screenshot"] = new(ScreenshotCommand.Run, ScreenshotCommand.Help),
    ["wait"] = new(WaitCommand.Run, WaitCommand.Help),
};

return Spy.Run(Args, Help, commands);
