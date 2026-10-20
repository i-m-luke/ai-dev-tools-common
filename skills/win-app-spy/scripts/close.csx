// close: closes an app this session launched — gracefully, or killed with `force: true`.
#nullable enable
#load "core.csx"

using System.Text.Json.Nodes;
using FlaUI.Core.AutomationElements;

public static class CloseCommand
{
    public const string Help = """
        Closes an app launched from this working folder: the active app, or the one `app` selects.

        Request
          { "command": "close", "force": false, "timeout": 10000 }
          force    true kills the app instead of closing its windows (default false).
          timeout  How long to wait for the app to exit, in ms (default 10000).

        Result data
          { "pid": 25776, "closed": "gracefully" }
          closed is gracefully (its windows were closed) or killed (force).

        Errors
          NOT_LAUNCHED (the app was not launched from this working folder; it stays open), TIMEOUT
          (the app still runs, e.g. it asks to save changes; send force: true), CLOSE_FAILED (no
          window to close; send force: true), APP_NOT_FOUND.
        """;

    public static JsonNode? Run(Request request)
    {
        var session = Session.Load();
        var target = Apps.Target(request, session);
        var force = request.Bool("force");
        var timeout = request.Int("timeout") ?? Poll.DefaultTimeoutMs;
        if (!session.Launched.Contains(target.Pid))
        {
            throw new SpyError(
                ErrorCodes.NotLaunched,
                $"Process {target.Pid} was not launched in this session; close closes only apps started by launch.");
        }

        System.Diagnostics.Process process;
        try { process = Apps.Process(target.Pid); }
        catch (SpyError)
        {
            session.Forget(target.Pid);
            session.Save();
            throw;
        }

        using (process)
        {
            if (force) process.Kill();
            else CloseWindows(target);

            if (!process.WaitForExit(timeout))
            {
                throw new SpyError(
                    ErrorCodes.Timeout,
                    $"Process {target.Pid} did not exit within {timeout} ms; it may be asking to save changes. Send force: true to kill it.");
            }
        }

        session.Forget(target.Pid);
        session.Save();
        return new JsonObject { ["pid"] = target.Pid, ["closed"] = force ? "killed" : "gracefully" };
    }

    private static void CloseWindows(ActiveApp target)
    {
        using var automation = Apps.CreateAutomation(target.Uia);
        var windows = Apps.TopLevelWindows(automation, new HashSet<int> { target.Pid });
        if (windows.Length == 0)
        {
            throw new SpyError(
                ErrorCodes.CloseFailed,
                $"Process {target.Pid} has no window to close; send force: true to kill it.");
        }

        foreach (var window in windows) window.AsWindow().Close();
    }
}
