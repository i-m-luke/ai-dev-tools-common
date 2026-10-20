// get-state: resolves each locator against the target app's windows and reports its element's requested state.
#nullable enable
#load "core.csx"

using System.Text.Json.Nodes;

public static class GetStateCommand
{
    public const string Help = """
        Reads the requested state of the element each locator matches.

        Request
          { "command": "get-state",
            "locators": [ "//MenuItem[@AutomationId='File']", { "xpath": "//MenuBar/MenuItem", "all": true } ],
            "states": [ "name", "enabled" ] }
          locators  Required; xpaths (the subset in references/xpath.md), or { "xpath": "…", "all": true }
                    to collect every match.
          states    The state keys to read (see --help); without them each item only confirms that
                    its locator matches exactly one element.

        Result data
          { "elements": [
              { "xpath": "//MenuItem[@AutomationId='File']", "state": { "name": "File", "enabled": true } },
              { "xpath": "//MenuBar/MenuItem", "matches": [
                  { "xpath": "/Window/Pane[4]/Pane/MenuBar/MenuItem[@AutomationId='File']", "state": { … } }, … ] },
              { "xpath": "//Button[@AutomationId='SaveBtn']",
                "error": { "code": "ELEMENT_NOT_FOUND", "message": "No element matched." } } ] }
          One item per locator; its xpath echoes the locator exactly, so match items to locators by
          it, not by order. A one-element locator's item carries state. An "all" locator's item
          carries matches: every match in document order with its concrete xpath (no match: only
          xpath), never AMBIGUOUS_MATCH. A failed locator's item carries error, and the other items
          keep their results.

        Item errors
          ELEMENT_NOT_FOUND; AMBIGUOUS_MATCH with count (all matches) and candidates (the first 5
          in document order as { xpath, state }, each with the concrete xpath of that one element);
          INVALID_REQUEST (the xpath is outside the supported subset).

        Errors
          APP_NOT_FOUND, INVALID_REQUEST.
        """;

    public static JsonNode? Run(Request request)
    {
        var locators = Locator.Specs(request);
        var states = ElementState.Requested(request);
        var target = Apps.Target(request, Session.Load());
        using (Apps.Process(target.Pid)) { }

        using var automation = Apps.CreateAutomation(target.Uia);
        var root = Locator.Root(automation, target.Pid);
        var elements = locators.Select(locator => (JsonNode)Element(root, locator, states)).ToArray();
        return new JsonObject { ["elements"] = new JsonArray(elements) };
    }

    // One item per locator; a failing locator gets its error and leaves the other items intact.
    private static JsonObject Element(UiNode root, LocatorSpec locator, IReadOnlyList<string>? states)
    {
        try
        {
            if (locator.All)
            {
                var matches = Locator.Resolve(root, locator.XPath).Select(n => (JsonNode)Locator.Item(n, states)).ToArray();
                return new JsonObject { ["xpath"] = locator.XPath, ["matches"] = new JsonArray(matches) };
            }

            var node = Locator.Single(root, locator.XPath, states);
            return new JsonObject { ["xpath"] = locator.XPath, ["state"] = ElementState.Read(node.Element!, states) };
        }
        catch (Exception e)
        {
            return new JsonObject { ["xpath"] = locator.XPath, ["error"] = Envelope.Error(e) };
        }
    }
}
