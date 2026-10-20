// Shared core of win-app-spy: the output contract, request parsing, session state and app connection.
// The main script loads it with #load "core.csx", ad hoc scripts by its full path.
#nullable enable
#r "nuget: FlaUI.UIA3, 5.0.0"
// Restored for its DLL only: Apps.CreateAutomation loads UIA2 in a context of its own.
#r "nuget: FlaUI.UIA2, 5.0.0"
#load "locator.csx"

using System.ComponentModel;
using System.Diagnostics;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Runtime.Loader;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Threading;
using FlaUI.Core;
using FlaUI.Core.AutomationElements;
using FlaUI.UIA3;

/// <summary>
/// A failure reported as an error object: thrown from a command it goes to stderr in place of the result,
/// caught per item it sits on that item. <paramref name="details"/> adds fields to the error object.
/// </summary>
public class SpyError(string code, string message, JsonObject? details = null) : Exception(message)
{
    public string Code { get; } = code;

    public JsonObject? Details { get; } = details;

    public JsonObject ToJson()
    {
        var error = Envelope.Error(Code, Message);
        if (Details is not null)
            foreach (var (name, value) in Details) error[name] = value?.DeepClone();
        return error;
    }
}

public static class ErrorCodes
{
    public const string InvalidRequest = "INVALID_REQUEST";
    public const string UnknownCommand = "UNKNOWN_COMMAND";
    public const string AppNotFound = "APP_NOT_FOUND";
    public const string AppAlreadyRunning = "APP_ALREADY_RUNNING";
    public const string AppAmbiguous = "APP_AMBIGUOUS";
    public const string NotLaunched = "NOT_LAUNCHED";
    public const string CloseFailed = "CLOSE_FAILED";
    public const string ElementNotFound = "ELEMENT_NOT_FOUND";
    public const string AmbiguousMatch = "AMBIGUOUS_MATCH";
    public const string ActionFailed = "ACTION_FAILED";
    public const string Timeout = "TIMEOUT";
    public const string Unexpected = "UNEXPECTED";
}

/// <summary>A request read from the request file, with typed access to its fields.</summary>
public sealed class Request(JsonObject json)
{
    public JsonObject Json { get; } = json;

    public string? Command => String("command");

    public static Request Load(string path)
    {
        string text;
        try { text = File.ReadAllText(path); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            throw new SpyError(ErrorCodes.InvalidRequest, $"Cannot read the request file '{path}': {e.Message}");
        }

        JsonNode? node;
        try { node = JsonNode.Parse(text); }
        catch (JsonException e) { throw new SpyError(ErrorCodes.InvalidRequest, $"The request is not valid JSON: {e.Message}"); }

        return node is JsonObject json
            ? new Request(json)
            : throw new SpyError(ErrorCodes.InvalidRequest, "The request must be a JSON object.");
    }

    public string? String(string name) =>
        Field(name) switch
        {
            null => null,
            JsonValue value when value.TryGetValue(out string? text) => text,
            _ => throw Invalid(name, "a string"),
        };

    public string RequiredString(string name) =>
        String(name) is { Length: > 0 } text ? text : throw Invalid(name, "a non-empty string");

    public int? Int(string name) =>
        Field(name) switch
        {
            null => null,
            JsonValue value when value.TryGetValue(out int number) => number,
            _ => throw Invalid(name, "an integer"),
        };

    public bool Bool(string name) =>
        Field(name) switch
        {
            null => false,
            JsonValue value when value.TryGetValue(out bool flag) => flag,
            _ => throw Invalid(name, "true or false"),
        };

    public JsonObject? Object(string name) =>
        Field(name) switch
        {
            null => null,
            JsonObject obj => obj,
            _ => throw Invalid(name, "an object"),
        };

    public JsonArray? Array(string name) =>
        Field(name) switch
        {
            null => null,
            JsonArray array => array,
            _ => throw Invalid(name, "a list"),
        };

    private JsonNode? Field(string name) => Json.TryGetPropertyValue(name, out var node) ? node : null;

    private static SpyError Invalid(string name, string expected) =>
        new(ErrorCodes.InvalidRequest, $"'{name}' must be {expected}.");
}

/// <summary>
/// The output contract: the result <c>{ command, data }</c> on one <c>::result::</c> stdout line, an error
/// object on stderr; empty fields are omitted.
/// </summary>
public static class Envelope
{
    public const string ResultPrefix = "::result::";

    private static readonly JsonSerializerOptions Options = new()
    {
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };

    public static JsonObject Error(string code, string message) =>
        new() { ["code"] = code, ["message"] = message };

    /// <summary>The error object for an exception: a <see cref="SpyError"/>'s own, otherwise UNEXPECTED.</summary>
    public static JsonObject Error(Exception exception) =>
        exception is SpyError spyError
            ? spyError.ToJson()
            : Error(ErrorCodes.Unexpected, $"{exception.GetType().Name}: {exception.Message}");

    /// <summary>
    /// Runs <paramref name="handler"/> and prints its outcome; returns the exit code: 0 with the result,
    /// 2 with a <see cref="SpyError"/>'s error object, 1 with the error object of any other exception.
    /// </summary>
    public static int Run(string? command, Func<JsonNode?> handler)
    {
        try { return Result(new JsonObject { ["command"] = command, ["data"] = handler() }); }
        catch (SpyError e) { return Fail(e.ToJson(), 2); }
        catch (Exception e) { return Fail(Error(e), 1); }
    }

    /// <summary>Prints the result line; returns 0.</summary>
    public static int Result(JsonObject result)
    {
        UseUtf8();
        Console.WriteLine(ResultPrefix + (Prune(result) ?? new JsonObject()).ToJsonString(Options));
        return 0;
    }

    /// <summary>Prints the error object to stderr; returns <paramref name="exitCode"/>.</summary>
    public static int Fail(JsonObject error, int exitCode)
    {
        UseUtf8();
        Console.Error.WriteLine((Prune(error) ?? new JsonObject()).ToJsonString(Options));
        return exitCode;
    }

    public static void UseUtf8() => Console.OutputEncoding = new System.Text.UTF8Encoding(false);

    // Returns a copy without nulls, empty strings, empty arrays and empty objects; null when nothing is left.
    private static JsonNode? Prune(JsonNode? node)
    {
        switch (node)
        {
            case JsonObject obj:
                var prunedObject = new JsonObject();
                foreach (var (name, value) in obj)
                    if (Prune(value) is { } prunedValue) prunedObject[name] = prunedValue;
                return prunedObject.Count > 0 ? prunedObject : null;
            case JsonArray array:
                var prunedArray = new JsonArray();
                foreach (var item in array)
                    if (Prune(item) is { } prunedItem) prunedArray.Add(prunedItem);
                return prunedArray.Count > 0 ? prunedArray : null;
            case JsonValue value when value.TryGetValue(out string? text) && text.Length == 0:
                return null;
            default:
                return node?.DeepClone();
        }
    }
}

public sealed record ActiveApp(int Pid, string Uia);

/// <summary>State kept between script runs in session.json in the working folder.</summary>
public sealed class Session
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
    };

    /// <summary>The app later requests target when they send no <c>app</c>.</summary>
    public ActiveApp? ActiveApp { get; set; }

    /// <summary>Pids started by <c>launch</c>; <c>close</c> closes only these.</summary>
    public List<int> Launched { get; set; } = [];

    public static string FilePath => Path.Combine(Spy.WorkingFolder, "session.json");

    public static Session Load() =>
        File.Exists(FilePath)
            ? JsonSerializer.Deserialize<Session>(File.ReadAllText(FilePath), Options) ?? new Session()
            : new Session();

    public void Save() => File.WriteAllText(FilePath, JsonSerializer.Serialize(this, Options));

    public void Forget(int pid)
    {
        Launched.Remove(pid);
        if (ActiveApp?.Pid == pid) ActiveApp = null;
    }
}

/// <summary>Connects to apps: UIA automation in the chosen mode, the target app and its windows.</summary>
public static class Apps
{
    public const string Uia2 = "UIA2";
    public const string Uia3 = "UIA3";

    public static string ParseUia(string? uia) =>
        uia?.ToUpperInvariant() switch
        {
            null => Uia3,
            Uia2 => Uia2,
            Uia3 => Uia3,
            _ => throw new SpyError(ErrorCodes.InvalidRequest, $"'uia' must be \"{Uia2}\" or \"{Uia3}\"."),
        };

    /// <summary>Creates the automation for a UIA mode; use it instead of constructing one directly.</summary>
    public static AutomationBase CreateAutomation(string uia)
    {
        DesktopRuntime.Register();
        return uia == Uia2 ? DesktopRuntime.CreateUia2Automation() : new UIA3Automation();
    }

    /// <summary>The pid and UIA mode a request targets: its <c>app</c>, otherwise the session's active app.</summary>
    public static ActiveApp Target(Request request, Session session)
    {
        var uia = request.String("uia");
        if (request.Object("app") is { } app)
        {
            var pid = Find(app, ParseUia(uia));
            var known = session.ActiveApp?.Pid == pid ? session.ActiveApp.Uia : null;
            return new ActiveApp(pid, ParseUia(uia ?? known));
        }

        return session.ActiveApp is { } active
            ? active with { Uia = ParseUia(uia ?? active.Uia) }
            : throw new SpyError(ErrorCodes.AppNotFound, "No active app; send 'app' or start one with launch or attach.");
    }

    /// <summary>
    /// The pid an <c>app</c> object selects: its <c>pid</c>, the one process named <c>process</c> that has
    /// a window, or the one process with a window whose title contains <c>title</c>.
    /// </summary>
    public static int Find(JsonObject app, string uia)
    {
        string[] selectors = ["pid", "process", "title"];
        var sent = selectors.Where(app.ContainsKey).ToArray();
        if (sent.Length != 1)
        {
            throw new SpyError(ErrorCodes.InvalidRequest, "'app' must hold exactly one of 'pid', 'process' or 'title'.");
        }

        var fields = new Request(app);
        if (sent[0] == "pid") return fields.Int("pid") ?? throw new SpyError(ErrorCodes.InvalidRequest, "'pid' must be an integer.");

        using var automation = CreateAutomation(uia);
        var windows = automation.GetDesktop().FindAllChildren();
        if (sent[0] == "process")
        {
            var name = fields.RequiredString("process");
            if (name.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)) name = name[..^4];
            var pids = System.Diagnostics.Process.GetProcessesByName(name).Select(process => process.Id).ToHashSet();
            return Single(windows.Where(window => pids.Contains(PidOf(window))), $"no process named '{name}' has a window");
        }

        var title = fields.RequiredString("title");
        return Single(
            windows.Where(window => TitleOf(window).Contains(title, StringComparison.OrdinalIgnoreCase)),
            $"no window title contains '{title}'");
    }

    // Several windows of one process are one match; windows of several processes are ambiguous.
    private static int Single(IEnumerable<AutomationElement> windows, string noMatch)
    {
        var matches = windows.GroupBy(PidOf).ToArray();
        return matches.Length switch
        {
            0 => throw new SpyError(ErrorCodes.AppNotFound, $"No app matches: {noMatch}."),
            1 => matches[0].Key,
            _ => throw new SpyError(
                ErrorCodes.AppAmbiguous,
                $"{matches.Length} apps match; send the pid of the one you mean: "
                + string.Join(", ", matches.Select(match => $"pid {match.Key} '{TitleOf(match.First())}'")) + "."),
        };
    }

    public static int PidOf(AutomationElement window) => window.Properties.ProcessId.ValueOrDefault;

    public static string TitleOf(AutomationElement window) => window.Properties.Name.ValueOrDefault ?? "";

    /// <summary>The running process with the pid, or APP_NOT_FOUND.</summary>
    public static Process Process(int pid)
    {
        try { return System.Diagnostics.Process.GetProcessById(pid); }
        catch (ArgumentException) { throw new SpyError(ErrorCodes.AppNotFound, $"No running process has pid {pid}."); }
    }

    /// <summary>Top-level windows (desktop children) owned by the processes.</summary>
    public static AutomationElement[] TopLevelWindows(AutomationBase automation, IReadOnlySet<int> pids) =>
        automation.GetDesktop().FindAllChildren()
            .Where(window => pids.Contains(window.Properties.ProcessId.ValueOrDefault))
            .ToArray();

    public static JsonObject Describe(AutomationElement window, ActiveApp app) =>
        new()
        {
            ["pid"] = app.Pid,
            ["title"] = window.Properties.Name.ValueOrDefault,
            ["uia"] = app.Uia,
        };
}

/// <summary>Repeats a probe until it yields a result or the timeout passes.</summary>
public static class Poll
{
    public const int DefaultTimeoutMs = 10_000;
    public const int DefaultIntervalMs = 250;

    /// <summary>A request's polling: <c>timeout</c> (ms, default 10000, at least 0) and <c>poll</c> (ms, default 250, at least 1).</summary>
    public sealed record Options(int TimeoutMs, int IntervalMs)
    {
        public static Options Read(Request request) => new(
            AtLeast(request, "timeout", 0, DefaultTimeoutMs),
            AtLeast(request, "poll", 1, DefaultIntervalMs));

        private static int AtLeast(Request request, string name, int minimum, int fallback) =>
            request.Int(name) is not { } value ? fallback
            : value >= minimum ? value
            : throw new SpyError(ErrorCodes.InvalidRequest, $"'{name}' must be an integer of at least {minimum} (ms).");
    }

    public static T? Until<T>(Func<T?> probe, Options options) where T : class =>
        Until(probe, options.TimeoutMs, options.IntervalMs);

    public static T? Until<T>(Func<T?> probe, int timeoutMs, int intervalMs = DefaultIntervalMs) where T : class
    {
        var clock = Stopwatch.StartNew();
        while (true)
        {
            if (probe() is { } result) return result;
            if (clock.ElapsedMilliseconds >= timeoutMs) return null;
            Thread.Sleep(intervalMs);
        }
    }
}

/// <summary>
/// dotnet-script compiles for plain net10.0, so the WindowsDesktop runtime assemblies FlaUI needs
/// (Accessibility for UIA3; UIAutomationClient and WindowsBase for UIA2) are loaded from the
/// installed Microsoft.WindowsDesktop.App into a load context of their own.
/// </summary>
public sealed class DesktopRuntime : AssemblyLoadContext
{
    private static DesktopRuntime? instance;
    private static readonly AssemblyLoadContext ScriptContext =
        GetLoadContext(typeof(AutomationBase).Assembly) ?? Default;
    private static readonly string NetCoreFolder = RuntimeEnvironment.GetRuntimeDirectory();

    private readonly string folder;

    private DesktopRuntime(string folder) : base("win-app-spy-desktop") => this.folder = folder;

    public static void Register()
    {
        if (instance is not null) return;
        instance = new DesktopRuntime(FindFolder());
        AppDomain.CurrentDomain.AssemblyResolve += (_, args) =>
            instance.Owns(new AssemblyName(args.Name)) ? instance.LoadFromAssemblyName(new AssemblyName(args.Name)) : null;
    }

    public static AutomationBase CreateUia2Automation()
    {
        var core = new FileInfo(typeof(AutomationBase).Assembly.Location);
        var lib = core.Directory!;
        var packages = lib.Parent!.Parent!.Parent!.Parent!;
        var uia2 = Path.Combine(packages.FullName, "flaui.uia2", lib.Parent.Parent.Name, "lib", lib.Name, "FlaUI.UIA2.dll");
        var type = instance!.LoadFromAssemblyPath(uia2).GetType("FlaUI.UIA2.UIA2Automation", throwOnError: true)!;
        return (AutomationBase)Activator.CreateInstance(type)!;
    }

    protected override Assembly? Load(AssemblyName name)
    {
        if (name.Name == typeof(AutomationBase).Assembly.GetName().Name) return typeof(AutomationBase).Assembly;
        if (Owns(name)) return LoadFromAssemblyPath(PathOf(name));
        if (!string.IsNullOrEmpty(name.CultureName)) return null;
        try { return ScriptContext.LoadFromAssemblyName(name); }
        catch (FileNotFoundException) { return null; }
    }

    // WindowsBase also ships as a facade in Microsoft.NETCore.App; UIA2 needs the WindowsDesktop one.
    private bool Owns(AssemblyName name) =>
        string.IsNullOrEmpty(name.CultureName)
        && File.Exists(PathOf(name))
        && (name.Name == "WindowsBase" || !File.Exists(Path.Combine(NetCoreFolder, name.Name + ".dll")));

    private string PathOf(AssemblyName name) => Path.Combine(folder, name.Name + ".dll");

    private static string FindFolder()
    {
        var shared = Path.GetFullPath(Path.Combine(NetCoreFolder, "..", ".."));
        var desktop = new DirectoryInfo(Path.Combine(shared, "Microsoft.WindowsDesktop.App"));
        var exact = Path.Combine(desktop.FullName, Environment.Version.ToString());
        if (Directory.Exists(exact)) return exact;
        var sameMajor = desktop.Exists
            ? desktop.GetDirectories($"{Environment.Version.Major}.*")
                .Select(dir => (dir, version: Version.TryParse(dir.Name, out var v) ? v : null))
                .Where(entry => entry.version is not null)
                .OrderByDescending(entry => entry.version)
                .Select(entry => entry.dir.FullName)
                .FirstOrDefault()
            : null;
        return sameMajor ?? throw new SpyError(
            ErrorCodes.Unexpected,
            $"The .NET Desktop Runtime {Environment.Version.Major} is missing; install it from https://dotnet.microsoft.com/download.");
    }
}

/// <summary>A command of the main script: its handler and its help, whose first line summarises it.</summary>
public sealed record Command(Func<Request, JsonNode?> Run, string Help);

/// <summary>Entry points of the main script and of ad hoc scripts: parse the arguments and run.</summary>
public static class Spy
{
    /// <summary>The folder holding the request file, session.json and the screenshots.</summary>
    public static string WorkingFolder { get; private set; } = "";

    /// <summary>The main script: <c>--new-working-folder</c>, <c>--request-path &lt;file&gt;</c> or <c>--help [&lt;command&gt;]</c>.</summary>
    public static int Run(IList<string> args, string help, IReadOnlyDictionary<string, Command> commands)
    {
        if (args.Count >= 1 && args[0] == "--help") return PrintHelp(args, help, commands);
        if (args.Count == 1 && args[0] == "--new-working-folder")
        {
            try { return NewWorkingFolder(); }
            catch (Exception e) { return Envelope.Fail(Envelope.Error(e), 1); }
        }

        return RunRequest(args, request =>
        {
            var command = request.String("command")
                ?? throw new SpyError(ErrorCodes.InvalidRequest, "'command' is missing.");
            return commands.TryGetValue(command, out var handler)
                ? handler.Run(request)
                : throw new SpyError(ErrorCodes.UnknownCommand, $"Unknown command '{command}'; known commands: {string.Join(", ", commands.Keys.Order())}.");
        });
    }

    /// <summary>An ad hoc script: runs <paramref name="handler"/> on the request <c>--request-path</c> names.</summary>
    public static int Run(IList<string> args, string command, Func<Request, JsonNode?> handler) =>
        RunRequest(args, handler, command);

    private static int RunRequest(IList<string> args, Func<Request, JsonNode?> handler, string? command = null)
    {
        Request request;
        try
        {
            var path = args.Count == 2 && args[0] == "--request-path"
                ? Path.GetFullPath(args[1])
                : throw new SpyError(ErrorCodes.InvalidRequest, "Pass --request-path <file>, --new-working-folder or --help [<command>].");
            request = Request.Load(path);
            WorkingFolder = Path.GetDirectoryName(path)!;
        }
        catch (SpyError e) { return Envelope.Fail(e.ToJson(), 2); }

        return Envelope.Run(command ?? SafeCommand(request), () => handler(request));
    }

    private static string? SafeCommand(Request request) =>
        request.Json["command"] is JsonValue value && value.TryGetValue(out string? command) ? command : null;

    // One folder per conversation; a suffix keeps folders created within the same second apart.
    private static int NewWorkingFolder()
    {
        var parent = Path.Combine(Path.GetTempPath(), "win-app-spy");
        var name = DateTime.Now.ToString("yyyyMMdd-HHmmss");
        var folder = Path.Combine(parent, name);
        for (var suffix = 2; Directory.Exists(folder); suffix++) folder = Path.Combine(parent, $"{name}-{suffix}");
        Directory.CreateDirectory(folder);
        return Envelope.Result(new JsonObject { ["workingFolder"] = folder });
    }

    private static int PrintHelp(IList<string> args, string help, IReadOnlyDictionary<string, Command> commands)
    {
        Envelope.UseUtf8();
        if (args.Count == 1)
        {
            var width = commands.Keys.Max(name => name.Length);
            var list = commands.OrderBy(pair => pair.Key, StringComparer.Ordinal)
                .Select(pair => $"  {pair.Key.PadRight(width)}  {pair.Value.Help.Split('\n')[0].Trim()}");
            Console.WriteLine(help.TrimEnd() + "\n\nCommands (details: --help <command>):\n" + string.Join("\n", list));
            return 0;
        }

        if (args.Count == 2 && commands.TryGetValue(args[1], out var command))
        {
            Console.WriteLine($"{args[1]} — {command.Help.TrimEnd()}");
            return 0;
        }

        return Envelope.Fail(
            Envelope.Error(ErrorCodes.UnknownCommand, $"Pass --help or --help <command>; known commands: {string.Join(", ", commands.Keys.Order())}."),
            2);
    }
}
