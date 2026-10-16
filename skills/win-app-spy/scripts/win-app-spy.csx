// win-app-spy main script: dotnet script win-app-spy.csx -- req.json
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

// To add a command: write <command>.csx with a handler `JsonNode? Run(Request)`, #load it above
// and add its entry here, keeping both lists alphabetical.
var commands = new Dictionary<string, Func<Request, System.Text.Json.Nodes.JsonNode?>>
{
    ["act"] = ActCommand.Run,
    ["attach"] = AttachCommand.Run,
    ["close"] = CloseCommand.Run,
    ["dump-tree"] = DumpTreeCommand.Run,
    ["get-state"] = GetStateCommand.Run,
    ["launch"] = LaunchCommand.Run,
    ["screenshot"] = ScreenshotCommand.Run,
    ["wait"] = WaitCommand.Run,
};

return Spy.Run(Args, commands);
