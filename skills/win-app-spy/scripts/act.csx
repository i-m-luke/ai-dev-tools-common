// act: performs one action on the one element a locator matches, then reports the element's requested state.
#nullable enable
#load "core.csx"

using System.Text.Json.Nodes;
using FlaUI.Core;
using FlaUI.Core.AutomationElements;
using FlaUI.Core.Input;
using FlaUI.Core.Patterns;
using FlaUI.Core.Patterns.Infrastructure;
using FlaUI.Core.WindowsAPI;

public static class ActCommand
{
    // Time the UI gets to react before the state after the action is read.
    private const int SettleMs = 300;

    // Each entry reads the action's own request fields up front, so a bad request fails before anything is touched.
    private static readonly Dictionary<string, Func<Request, Action<UiNode>>> Actions = new()
    {
        ["click"] = _ => node => node.Element!.Click(),
        ["doubleClick"] = _ => node => node.Element!.DoubleClick(),
        ["rightClick"] = _ => node => node.Element!.RightClick(),
        ["focus"] = _ => node => node.Element!.Focus(),
        ["type"] = request =>
        {
            var text = request.RequiredString("text");
            return node =>
            {
                node.Element!.Focus();
                Keyboard.Type(text);
            };
        },
        ["setValue"] = request =>
        {
            var value = request.String("value") ?? throw new SpyError(ErrorCodes.InvalidRequest, "'value' must be a string.");
            return node => Supported(node.Element!.Patterns.Value, "setValue", "Value").SetValue(value);
        },
        ["invoke"] = _ => node => Supported(node.Element!.Patterns.Invoke, "invoke", "Invoke").Invoke(),
        ["toggle"] = _ => node => Supported(node.Element!.Patterns.Toggle, "toggle", "Toggle").Toggle(),
        ["select"] = _ => node => Supported(node.Element!.Patterns.SelectionItem, "select", "SelectionItem").Select(),
        ["expand"] = _ => node => Supported(node.Element!.Patterns.ExpandCollapse, "expand", "ExpandCollapse").Expand(),
        ["collapse"] = _ => node => Supported(node.Element!.Patterns.ExpandCollapse, "collapse", "ExpandCollapse").Collapse(),
        ["key"] = request =>
        {
            var keys = Keys(request.RequiredString("keys"));
            return node =>
            {
                node.Element!.Focus();
                Keyboard.TypeSimultaneously(keys);
            };
        },
    };

    public static JsonNode? Run(Request request)
    {
        var locator = Locator.Spec(request.Json["locator"], "locator");
        if (locator.All) throw new SpyError(ErrorCodes.InvalidRequest, "'locator' of act must match one element; leave out 'all'.");
        var action = request.RequiredString("action");
        var perform = Actions.TryGetValue(action, out var prepare)
            ? prepare(request)
            : throw new SpyError(ErrorCodes.InvalidRequest, $"'action' must be one of: {string.Join(", ", Actions.Keys)}.");
        var states = ElementState.Requested(request);
        var target = Apps.Target(request, Session.Load());
        using (Apps.Process(target.Pid)) { }

        using var automation = Apps.CreateAutomation(target.Uia);
        var node = Locator.Single(Locator.Root(automation, target.Pid), locator.XPath, states);
        try
        {
            perform(node);
        }
        catch (Exception e) when (e is not SpyError)
        {
            throw new SpyError(ErrorCodes.ActionFailed, $"{action} failed: {e.Message}");
        }

        if (states is not null) global::System.Threading.Thread.Sleep(SettleMs);
        return new JsonObject { ["xpath"] = locator.XPath, ["state"] = ElementState.Read(node.Element!, states) };
    }

    // "Ctrl+Shift+S", "Escape", "Enter", "A": modifiers and one key, joined by '+'.
    private static VirtualKeyShort[] Keys(string keys) =>
        keys.Split('+', StringSplitOptions.TrimEntries).Select(Key).ToArray();

    private static VirtualKeyShort Key(string name)
    {
        var upper = name.ToUpperInvariant() switch
        {
            "CTRL" => "CONTROL",
            "WIN" => "LWIN",
            "BACKSPACE" => "BACK",
            "DEL" => "DELETE",
            "PAGEUP" => "PRIOR",
            "PAGEDOWN" => "NEXT",
            var single when single.Length == 1 && char.IsAsciiLetterOrDigit(single[0]) => "KEY_" + single,
            var other => other,
        };
        return Enum.TryParse<VirtualKeyShort>(upper, ignoreCase: false, out var key) && upper.Length > 0
            ? key
            : throw new SpyError(ErrorCodes.InvalidRequest, $"'keys' has an unknown key '{name}'; use e.g. Ctrl+A, Enter, Escape, Tab, Delete, F5.");
    }

    private static T Supported<T>(IAutomationPattern<T> pattern, string action, string patternName) where T : IPattern =>
        pattern.PatternOrDefault ?? throw new SpyError(
            ErrorCodes.ActionFailed,
            $"The element does not support {action} (no {patternName} pattern); try click.");
}
