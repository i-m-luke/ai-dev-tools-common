// screenshot: captures a window of the target app, or one element of it, as a PNG in the working folder.
#nullable enable
#r "nuget: System.Drawing.Common, 8.0.10"
#load "core.csx"

using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text.Json.Nodes;
using FlaUI.Core.Definitions;

public static class ScreenshotCommand
{
    public const string Help = """
        Captures the app's front window, or one element of it, as a PNG in the working folder.

        Request
          { "command": "screenshot", "xpath": "//MenuItem[@AutomationId='File']" }
          xpath  Captures just the one element it matches (default: the app's front window). To
                 capture another top-level window, send its xpath, e.g. //Window[@AutomationId='…'].

        Result data
          { "path": "C:\\…\\win-app-spy\\20261016-103311\\screenshot-20261016-103316-005.png",
            "window": { "handle": 4850202, "title": "Untitled - Notepad" },
            "element": "//MenuItem[@AutomationId='File']" }
          path is the PNG's full path; window is the window the image comes from; element echoes
          the request's xpath. The image comes from the window's own rendering: a window behind
          others comes out whole, and nothing is brought to the front.

        Errors
          ELEMENT_NOT_FOUND / AMBIGUOUS_MATCH / INVALID_REQUEST for the xpath (no file is written),
          UNEXPECTED for a minimized window or an element with no visible area (the message says
          which), APP_NOT_FOUND.
        """;

    public static JsonNode? Run(Request request)
    {
        var xpath = request.String("xpath");
        var target = Apps.Target(request, Session.Load());
        using (Apps.Process(target.Pid)) { }

        WindowCapture.UsePhysicalPixels();
        using var automation = Apps.CreateAutomation(target.Uia);
        var root = Locator.Root(automation, target.Pid);
        var node = xpath is null ? FrontWindow(root, target.Pid) : Locator.Single(root, xpath);
        var window = WindowOf(node);
        var handle = window.Element!.Properties.NativeWindowHandle.ValueOrDefault;
        var path = Path.Combine(Spy.WorkingFolder, $"screenshot-{DateTime.Now:yyyyMMdd-HHmmss-fff}.png");
        WindowCapture.Save(handle, xpath is null ? null : node.Element!.BoundingRectangle, path);
        return new JsonObject
        {
            ["path"] = path,
            ["window"] = new JsonObject { ["handle"] = handle.ToInt64(), ["title"] = Apps.TitleOf(window.Element!) },
            ["element"] = xpath,
        };
    }

    // The app's top-level windows come in z-order, so the first one is in front.
    private static UiNode FrontWindow(UiNode root, int pid) =>
        root.Children.FirstOrDefault()
        ?? throw new SpyError(ErrorCodes.AppNotFound, $"The app with pid {pid} has no window.");

    // The window an element is drawn in: its nearest Window with a handle, at most its top-level window.
    private static UiNode WindowOf(UiNode node)
    {
        for (var current = node; ; current = current.Parent!)
        {
            if (current.Parent!.IsRoot) return current;
            if (current.ControlType == ControlType.Window && current.Element!.Properties.NativeWindowHandle.ValueOrDefault != IntPtr.Zero)
                return current;
        }
    }
}

/// <summary>
/// Captures a window from its own rendering (PrintWindow), so windows behind others or partly
/// off screen come out whole and nothing is brought to the front.
/// </summary>
public static class WindowCapture
{
    private const uint RenderFullContent = 2;
    private const int ExtendedFrameBounds = 9;
    private static readonly IntPtr PerMonitorAwareV2 = new(-4);

    /// <summary>Makes element bounds and window rectangles both physical pixels on scaled displays.</summary>
    public static void UsePhysicalPixels() => SetProcessDpiAwarenessContext(PerMonitorAwareV2);

    /// <summary>Saves the window's visible frame, or just <paramref name="area"/> (screen pixels) of it, as a PNG.</summary>
    public static void Save(IntPtr window, Rectangle? area, string path)
    {
        if (IsIconic(window))
            throw new SpyError(ErrorCodes.Unexpected, "The window is minimized, so it has no image; ask the user to restore it.");
        if (!GetWindowRect(window, out var bounds))
            throw new SpyError(ErrorCodes.Unexpected, "The window is gone.");

        var windowRect = bounds.ToRectangle();
        var frame = DwmGetWindowAttribute(window, ExtendedFrameBounds, out var visible, Marshal.SizeOf<Rect>()) == 0
            ? visible.ToRectangle()
            : windowRect;
        var crop = Rectangle.Intersect(frame, area ?? frame);
        if (crop.Width <= 0 || crop.Height <= 0)
            throw new SpyError(ErrorCodes.Unexpected, "The element has no visible area in its window (hidden or scrolled away).");

        using var image = new Bitmap(windowRect.Width, windowRect.Height, PixelFormat.Format24bppRgb);
        using (var graphics = Graphics.FromImage(image))
        {
            var dc = graphics.GetHdc();
            try
            {
                if (!PrintWindow(window, dc, RenderFullContent))
                    throw new SpyError(ErrorCodes.Unexpected, "The window could not be captured.");
            }
            finally { graphics.ReleaseHdc(dc); }
        }

        crop.Offset(-windowRect.Left, -windowRect.Top);
        using var cropped = image.Clone(crop, PixelFormat.Format24bppRgb);
        cropped.Save(path, ImageFormat.Png);
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct Rect
    {
        public int Left, Top, Right, Bottom;

        public readonly Rectangle ToRectangle() => Rectangle.FromLTRB(Left, Top, Right, Bottom);
    }

    [DllImport("user32.dll")]
    private static extern bool SetProcessDpiAwarenessContext(IntPtr value);

    [DllImport("user32.dll")]
    private static extern bool IsIconic(IntPtr window);

    [DllImport("user32.dll")]
    private static extern bool GetWindowRect(IntPtr window, out Rect rect);

    [DllImport("user32.dll")]
    private static extern bool PrintWindow(IntPtr window, IntPtr dc, uint flags);

    [DllImport("dwmapi.dll")]
    private static extern int DwmGetWindowAttribute(IntPtr window, int attribute, out Rect value, int size);
}
