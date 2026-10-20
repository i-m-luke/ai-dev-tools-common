// wait: polls a locator until its element meets a condition, or answers TIMEOUT.
#nullable enable
#load "core.csx"

using System.Text.Json.Nodes;

public static class WaitCommand
{
    public const string Help = """
        Polls a locator until its element meets a condition.

        Request
          { "command": "wait", "locator": "//MenuItem[@AutomationId='File']", "condition": "enabled", "timeout": 5000 }
          locator    Required; an xpath.
          condition  exists (default; the locator matches one element), gone (it matches nothing),
                     enabled (the one match is enabled) or visible (the one match is not offscreen).
          timeout    How long to poll, in ms (default 10000).
          poll       How often to take a fresh look at the UI, in ms (default 250, at least 1).

        Result data
          { "xpath": "//MenuItem[@AutomationId='File']", "condition": "enabled" }

        Errors
          TIMEOUT (the condition did not hold in time), AMBIGUOUS_MATCH (at once, when the locator
          matches several elements), APP_NOT_FOUND, INVALID_REQUEST.
        """;

    private static readonly Dictionary<string, (string Verb, Func<IReadOnlyList<UiNode>, bool> Met)> Conditions = new()
    {
        ["exists"] = ("exist", matches => matches.Count == 1),
        ["gone"] = ("disappear", matches => matches.Count == 0),
        ["enabled"] = ("become enabled", matches => matches.Count == 1 && matches[0].Element!.Properties.IsEnabled.ValueOrDefault),
        ["visible"] = ("become visible", matches => matches.Count == 1 && !matches[0].Element!.Properties.IsOffscreen.ValueOrDefault),
    };

    public static JsonNode? Run(Request request)
    {
        var locator = Locator.Spec(request.Json["locator"], "locator");
        if (locator.All) throw new SpyError(ErrorCodes.InvalidRequest, "'locator' of wait must match one element; leave out 'all'.");
        Locator.Parse(locator.XPath);
        var name = request.String("condition") ?? "exists";
        var condition = Conditions.TryGetValue(name, out var found)
            ? found
            : throw new SpyError(ErrorCodes.InvalidRequest, $"'condition' must be one of: {string.Join(", ", Conditions.Keys)}.");
        var polling = Poll.Options.Read(request);
        var target = Apps.Target(request, Session.Load());
        using (Apps.Process(target.Pid)) { }

        using var automation = Apps.CreateAutomation(target.Uia);
        // A fresh root per poll: a root caches the tree it has walked.
        var met = Poll.Until(() =>
        {
            var matches = Locator.Resolve(Locator.Root(automation, target.Pid), locator.XPath);
            if (matches.Count > 1) throw Locator.Ambiguous(matches, null);
            return condition.Met(matches) ? matches : null;
        }, polling);

        return met is not null
            ? new JsonObject { ["xpath"] = locator.XPath, ["condition"] = name }
            : throw new SpyError(
                ErrorCodes.Timeout,
                $"'{locator.XPath}' did not {condition.Verb} within {polling.TimeoutMs} ms (polled every {polling.IntervalMs} ms).");
    }
}
