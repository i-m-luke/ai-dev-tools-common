// attach: connects to a running app by pid, process name or window title and makes it the active app.
#nullable enable
#load "core.csx"

using System.Text.Json.Nodes;

public static class AttachCommand
{
    public static JsonNode? Run(Request request)
    {
        var selector = request.Object("app") ?? throw new SpyError(
            ErrorCodes.InvalidRequest,
            "'app' is missing; send { \"pid\": 1234 }, { \"process\": \"notepad\" } or { \"title\": \"…\" }.");
        var session = Session.Load();
        var app = Apps.Target(request, session);
        Apps.Process(app.Pid).Dispose(); // APP_NOT_FOUND when no process has the pid

        using var automation = Apps.CreateAutomation(app.Uia);
        var windows = Apps.TopLevelWindows(automation, new HashSet<int> { app.Pid });
        var title = selector["title"] is JsonValue value && value.TryGetValue(out string? text) ? text : "";
        var window = windows.FirstOrDefault(window => Apps.TitleOf(window).Contains(title, StringComparison.OrdinalIgnoreCase))
            ?? throw new SpyError(ErrorCodes.AppNotFound, $"Process {app.Pid} has no window to inspect.");

        // Attaching never records the app as launched, so close keeps refusing it.
        session.ActiveApp = app;
        session.Save();
        return new JsonObject { ["app"] = Apps.Describe(window, app) };
    }
}
