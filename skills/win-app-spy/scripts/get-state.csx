// get-state: resolves each locator against the target app's windows and reports its element's requested state.
#nullable enable
#load "core.csx"

using System.Text.Json.Nodes;

public static class GetStateCommand
{
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
