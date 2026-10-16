// dump-tree: lists the target app's element tree, breadth-first and bounded, with a concrete xpath per node.
#nullable enable
#load "core.csx"

using System.Text.Json.Nodes;

public static class DumpTreeCommand
{
    public const int DefaultDepth = 4;
    public const int DefaultMaxNodes = 300;

    public static JsonNode? Run(Request request)
    {
        var rootXPath = request.String("root");
        var depth = AtLeastOne(request, "depth", DefaultDepth);
        var maxNodes = AtLeastOne(request, "maxNodes", DefaultMaxNodes);
        var includeOffscreen = request.Bool("includeOffscreen");
        var states = ElementState.Requested(request);
        var target = Apps.Target(request, Session.Load());
        using (Apps.Process(target.Pid)) { }

        using var automation = Apps.CreateAutomation(target.Uia);
        var root = Locator.Root(automation, target.Pid);
        var start = rootXPath is null ? root : Locator.Single(root, rootXPath, states);
        return new Dump(states, includeOffscreen, depth, maxNodes).Run(start);
    }

    private static int AtLeastOne(Request request, string name, int fallback) =>
        request.Int(name) switch
        {
            null => fallback,
            >= 1 and var value => value,
            _ => throw new SpyError(ErrorCodes.InvalidRequest, $"'{name}' must be an integer of at least 1."),
        };

    // Lists nodes level by level, so a cut by maxNodes keeps the upper levels whole.
    private sealed class Dump(IReadOnlyList<string>? states, bool includeOffscreen, int depth, int maxNodes)
    {
        private readonly Queue<(UiNode Node, JsonObject Json, int Level)> pending = new();
        private int listed;
        private bool truncated;

        // The virtual root stands for the whole app: its windows become data.nodes, its own fields go on data.
        public JsonObject Run(UiNode start)
        {
            var data = new JsonObject { ["truncated"] = false };
            if (start.IsRoot) pending.Enqueue((start, data, 0));
            else data["nodes"] = new JsonArray(List(start, 0));

            while (pending.TryDequeue(out var next)) Expand(next.Node, next.Json, next.Level);

            if (start.IsRoot && data["children"] is { } windows)
            {
                data.Remove("children");
                data["nodes"] = windows;
            }

            data["truncated"] = truncated;
            return data;
        }

        private JsonObject List(UiNode node, int level)
        {
            listed++;
            var json = new JsonObject { ["xpath"] = node.XPath, ["state"] = ElementState.Read(node.Element!, states) };
            pending.Enqueue((node, json, level));
            return json;
        }

        // Lists as many children as depth and maxNodes allow; childCount tells how many there are when some are left out.
        private void Expand(UiNode node, JsonObject json, int level)
        {
            var children = node.Children.Where(child => includeOffscreen || !IsOffscreen(child)).ToList();
            var shown = level < depth ? Math.Min(children.Count, maxNodes - listed) : 0;
            if (shown < children.Count)
            {
                json["childCount"] = children.Count;
                truncated = true;
            }

            if (shown > 0) json["children"] = new JsonArray(children.Take(shown).Select(child => (JsonNode)List(child, level + 1)).ToArray());
        }

        private static bool IsOffscreen(UiNode node) => node.Element!.Properties.IsOffscreen.ValueOrDefault;
    }
}
