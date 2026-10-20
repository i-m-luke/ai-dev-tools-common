// dump-tree: lists the target app's element tree, breadth-first and bounded, with a concrete xpath per node.
#nullable enable
#load "core.csx"

using System.Text.Json.Nodes;

public static class DumpTreeCommand
{
    public const string Help = """
        Lists the app's element tree, level by level, with a concrete xpath per node.

        Request
          { "command": "dump-tree", "depth": 2, "states": [ "name" ] }
          root              An xpath; lists the one element it matches and its descendants (default:
                            all the app's top-level windows).
          depth             Levels below the app or root (default 4).
          maxNodes          At most this many nodes (default 300).
          includeOffscreen  true lists offscreen elements too (default false; root itself is always
                            listed).
          states            The state keys to read per node (see --help).

        Result data
          { "truncated": true, "nodes": [
              { "xpath": "/Window", "state": { "name": "Untitled - Notepad" }, "children": [
                  { "xpath": "/Window/Pane[1]", "childCount": 1 } ] } ] }
          Each node carries its concrete xpath (send it to other commands as is), its state and its
          children. When the dump is cut, truncated is true and every node whose children were not
          all listed carries childCount (on data itself when windows were left out).

        Errors
          ELEMENT_NOT_FOUND / AMBIGUOUS_MATCH for root, APP_NOT_FOUND, INVALID_REQUEST.
        """;

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
