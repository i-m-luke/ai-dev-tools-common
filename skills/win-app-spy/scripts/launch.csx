// launch: starts an app, waits for its main window and makes it the session's active app.
#nullable enable
#load "core.csx"

using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text.Json.Nodes;
using FlaUI.Core;
using FlaUI.Core.AutomationElements;

public static class LaunchCommand
{
    public static JsonNode? Run(Request request)
    {
        var exe = request.RequiredString("exe");
        var arguments = request.String("args") ?? "";
        var polling = Poll.Options.Read(request);
        var timeout = polling.TimeoutMs;
        var uia = Apps.ParseUia(request.String("uia"));
        var processName = Path.GetFileNameWithoutExtension(exe);

        var session = Session.Load();
        using var automation = Apps.CreateAutomation(uia);
        var pidsBefore = Process.GetProcesses().Select(process => process.Id).ToHashSet();
        var sameNameBefore = PidsNamed(processName);
        var windowsBefore = Apps.TopLevelWindows(automation, sameNameBefore).Select(Handle).ToHashSet();

        using var started = Start(exe, arguments);
        // Some apps (e.g. Windows 11 Notepad) start through a launcher that exits and hands over to a
        // new process of the same name, or open the window in an instance that was already running.
        var found = Poll.Until(() =>
        {
            var launched = PidsNamed(processName).Where(pid => !pidsBefore.Contains(pid)).ToHashSet();
            if (!started.HasExited) launched.Add(started.Id);
            var window = Apps.TopLevelWindows(automation, launched.Union(sameNameBefore).ToHashSet())
                .FirstOrDefault(window => launched.Contains(Pid(window)) || !windowsBefore.Contains(Handle(window)));
            return window is null
                ? null
                : new Found(window, Pid(window), launched.Contains(Pid(window)) || session.Launched.Contains(Pid(window)));
        }, polling);

        if (found is null)
        {
            var stopped = Stop(started);
            throw new SpyError(
                ErrorCodes.Timeout,
                $"No window of '{exe}' appeared within {timeout} ms; "
                + (stopped ? $"the started process {started.Id} was stopped." : "a window that appears later is not tracked by this session."));
        }

        if (!found.Launched)
        {
            throw new SpyError(
                ErrorCodes.AppAlreadyRunning,
                $"'{exe}' opened its window in process {found.Pid}, which was already running and was not launched in this session, so close will not close it; close that app's windows and launch again.");
        }

        var app = new ActiveApp(found.Pid, uia);
        if (!session.Launched.Contains(app.Pid)) session.Launched.Add(app.Pid);
        session.ActiveApp = app;
        session.Save();
        return new JsonObject { ["app"] = Apps.Describe(found.Window, app) };
    }

    private sealed record Found(AutomationElement Window, int Pid, bool Launched);

    private static Process Start(string exe, string arguments)
    {
        StdHandles.StopInheritance();
        // CreateNoWindow keeps a console app off this script's console; GUI apps ignore it.
        var startInfo = new ProcessStartInfo(exe, arguments) { UseShellExecute = false, CreateNoWindow = true };
        try { return Process.Start(startInfo)!; }
        catch (Win32Exception e) { throw new SpyError(ErrorCodes.AppNotFound, $"Cannot start '{exe}': {e.Message}"); }
    }

    // A started app would otherwise inherit this script's stdin/stdout/stderr and keep the caller's
    // pipe open, so the caller would wait for the app to exit before reading the response.
    private static class StdHandles
    {
        private const int StdInput = -10, StdOutput = -11, StdError = -12;
        private const uint HandleFlagInherit = 1;

        public static void StopInheritance()
        {
            foreach (var std in new[] { StdInput, StdOutput, StdError })
                SetHandleInformation(GetStdHandle(std), HandleFlagInherit, 0);
        }

        [DllImport("kernel32.dll")]
        private static extern IntPtr GetStdHandle(int stdHandle);

        [DllImport("kernel32.dll")]
        private static extern bool SetHandleInformation(IntPtr handle, uint mask, uint flags);
    }

    private static bool Stop(Process started)
    {
        if (started.HasExited) return false;
        started.Kill();
        started.WaitForExit(Poll.DefaultTimeoutMs);
        return true;
    }

    private static HashSet<int> PidsNamed(string name) =>
        Process.GetProcessesByName(name).Select(process => process.Id).ToHashSet();

    private static int Pid(AutomationElement window) => window.Properties.ProcessId.ValueOrDefault;

    private static IntPtr Handle(AutomationElement window) => window.Properties.NativeWindowHandle.ValueOrDefault;
}
