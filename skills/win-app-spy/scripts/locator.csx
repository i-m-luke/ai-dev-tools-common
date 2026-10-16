// XPath locators of win-app-spy: parses an xpath, resolves it against the windows of the target app
// and describes the matched elements. Loaded by core.csx, so ad hoc scripts get it too.
//
//   var root = Locator.Root(automation, pid);           // virtual root over the app's top-level windows
//   var node = Locator.Single(root, xpath, states);     // exactly one match, else ELEMENT_NOT_FOUND / AMBIGUOUS_MATCH
//   var all = Locator.Resolve(root, xpath);             // every match, in document order
//   ElementState.Read(node.Element!, states);           // the requested state keys of an element
#nullable enable

using System.Text.Json.Nodes;
using FlaUI.Core;
using FlaUI.Core.AutomationElements;
using FlaUI.Core.Definitions;
using FlaUI.Core.Exceptions;

/// <summary>A locator item of a request: the xpath exactly as sent, and whether every match is wanted.</summary>
public sealed record LocatorSpec(string XPath, bool All);

public static class Locator
{
    public const int MaxCandidates = 5;

    /// <summary>The locators in the request's <paramref name="field"/>, a non-empty list of xpath strings.</summary>
    public static IReadOnlyList<LocatorSpec> Specs(Request request, string field = "locators")
    {
        var items = request.Array(field);
        if (items is null || items.Count == 0)
            throw new SpyError(ErrorCodes.InvalidRequest, $"'{field}' must be a non-empty list of xpaths.");
        return items.Select((item, index) => Spec(item, $"{field}[{index}]")).ToList();
    }

    /// <summary>An xpath string, or an object <c>{ "xpath": "...", "all": true }</c> asking for every match.</summary>
    public static LocatorSpec Spec(JsonNode? item, string field)
    {
        if (item is JsonValue value && value.TryGetValue(out string? xpath)) return new LocatorSpec(xpath, All: false);
        if (item is JsonObject obj && obj["xpath"] is JsonValue x && x.TryGetValue(out string? objectXPath))
        {
            if (obj["all"] is null) return new LocatorSpec(objectXPath, All: false);
            if (obj["all"] is JsonValue a && a.TryGetValue(out bool all)) return new LocatorSpec(objectXPath, all);
        }

        throw new SpyError(ErrorCodes.InvalidRequest, $"'{field}' must be an xpath string or {{ \"xpath\": string, \"all\": bool }}.");
    }

    /// <summary>The virtual root of the app <paramref name="pid"/>: its children are the app's top-level windows.</summary>
    public static UiNode Root(AutomationBase automation, int pid) => UiNode.CreateRoot(automation, pid);

    /// <summary>Parses an xpath; INVALID_REQUEST when it is not in the supported subset.</summary>
    public static XPath Parse(string xpath) => XPathParser.Parse(xpath);

    /// <summary>Every element the xpath matches, in document order; each carries its concrete xpath.</summary>
    public static IReadOnlyList<UiNode> Resolve(UiNode root, string xpath) => Parse(xpath).Evaluate(root);

    /// <summary>The one element the xpath matches; ELEMENT_NOT_FOUND or AMBIGUOUS_MATCH otherwise.</summary>
    public static UiNode Single(UiNode root, string xpath, IReadOnlyList<string>? states = null)
    {
        var matches = Resolve(root, xpath);
        return matches.Count switch
        {
            0 => throw new SpyError(ErrorCodes.ElementNotFound, "No element matched."),
            1 => matches[0],
            _ => throw Ambiguous(matches, states),
        };
    }

    /// <summary>AMBIGUOUS_MATCH with the match <c>count</c> and the first candidates as <see cref="Item"/>s.</summary>
    public static SpyError Ambiguous(IReadOnlyList<UiNode> matches, IReadOnlyList<string>? states) =>
        new(
            ErrorCodes.AmbiguousMatch,
            $"{matches.Count} elements matched; send the xpath of the intended candidate or narrow the xpath.",
            new JsonObject
            {
                ["count"] = matches.Count,
                ["candidates"] = new JsonArray(matches.Take(MaxCandidates).Select(match => (JsonNode)Item(match, states)).ToArray()),
            });

    /// <summary><c>{ xpath, state }</c> of a matched element, with its concrete xpath.</summary>
    public static JsonObject Item(UiNode node, IReadOnlyList<string>? states) =>
        new() { ["xpath"] = node.XPath, ["state"] = ElementState.Read(node.Element!, states) };
}

/// <summary>
/// An element of the tree an xpath is resolved against, with the concrete xpath that reaches it from
/// the virtual root. Properties and children are read once and cached, so a tree shows the UI as it
/// was when read; create a new root to see later changes.
/// </summary>
public sealed class UiNode
{
    private readonly AutomationBase automation;
    private readonly int pid;
    private IReadOnlyList<UiNode>? children;
    private ControlType? controlType;
    private string? automationId, name, className;

    private UiNode(AutomationBase automation, int pid, AutomationElement? element, UiNode? parent, int[] order)
    {
        this.automation = automation;
        this.pid = pid;
        Element = element;
        Parent = parent;
        Order = order;
    }

    /// <summary>The element; null for the virtual root.</summary>
    public AutomationElement? Element { get; }

    public UiNode? Parent { get; }

    public bool IsRoot => Element is null;

    /// <summary>The concrete xpath from the virtual root, one <c>/</c> step per level; empty for the root.</summary>
    public string XPath { get; private set; } = "";

    /// <summary>Child indexes from the root: compares nodes in document order.</summary>
    public int[] Order { get; }

    public ControlType ControlType => controlType ??= Element?.Properties.ControlType.ValueOrDefault ?? ControlType.Unknown;

    public string AutomationId => automationId ??= Element?.Properties.AutomationId.ValueOrDefault ?? "";

    public string Name => name ??= Element?.Properties.Name.ValueOrDefault ?? "";

    public string ClassName => className ??= Element?.Properties.ClassName.ValueOrDefault ?? "";

    /// <summary>The element's children in the control view; for the root, the app's top-level windows.</summary>
    public IReadOnlyList<UiNode> Children => children ??= ReadChildren();

    /// <summary>The value of an xpath attribute (<c>AutomationId</c>, <c>Name</c>, <c>ClassName</c>).</summary>
    public string Attribute(string attribute) =>
        attribute switch
        {
            XPathParser.AutomationId => AutomationId,
            XPathParser.Name => Name,
            XPathParser.ClassName => ClassName,
            _ => throw new ArgumentOutOfRangeException(nameof(attribute), attribute, null),
        };

    public static UiNode CreateRoot(AutomationBase automation, int pid) => new(automation, pid, null, null, []);

    /// <summary>The node and all its descendants, in document order.</summary>
    public IEnumerable<UiNode> DescendantsOrSelf()
    {
        yield return this;
        foreach (var child in Children)
            foreach (var node in child.DescendantsOrSelf())
                yield return node;
    }

    public static int CompareOrder(UiNode a, UiNode b)
    {
        for (var i = 0; i < Math.Min(a.Order.Length, b.Order.Length); i++)
            if (a.Order[i] != b.Order[i]) return a.Order[i].CompareTo(b.Order[i]);
        return a.Order.Length.CompareTo(b.Order.Length);
    }

    private IReadOnlyList<UiNode> ReadChildren()
    {
        var elements = new List<AutomationElement>();
        try
        {
            if (Element is null) elements.AddRange(Apps.TopLevelWindows(automation, new HashSet<int> { pid }));
            else
            {
                var walker = automation.TreeWalkerFactory.GetControlViewWalker();
                for (var child = walker.GetFirstChild(Element); child is not null; child = walker.GetNextSibling(child))
                    elements.Add(child);
            }
        }
        catch (ElementNotAvailableException)
        {
            // The element closed while being read; it has no children any more.
        }

        var nodes = elements.Select((element, index) => new UiNode(automation, pid, element, this, [.. Order, index])).ToList();
        foreach (var node in nodes) node.XPath = XPath + "/" + Segment(node, nodes);
        return nodes;
    }

    // The control type, narrowed among same-type siblings by a unique AutomationId, else by position.
    private static string Segment(UiNode node, IReadOnlyList<UiNode> siblings)
    {
        var type = node.ControlType.ToString();
        var sameType = siblings.Where(sibling => sibling.ControlType == node.ControlType).ToList();
        if (node.AutomationId.Length > 0
            && sameType.Count(sibling => sibling.AutomationId == node.AutomationId) == 1
            && XPathParser.Quote(node.AutomationId) is { } id)
        {
            return $"{type}[@{XPathParser.AutomationId}={id}]";
        }

        return sameType.Count == 1 ? type : $"{type}[{sameType.IndexOf(node) + 1}]";
    }
}

/// <summary>A parsed xpath: a chain of steps applied from the virtual root.</summary>
public sealed record XPath(IReadOnlyList<XPathStep> Steps)
{
    public IReadOnlyList<UiNode> Evaluate(UiNode root)
    {
        IReadOnlyList<UiNode> context = [root];
        foreach (var step in Steps) context = step.Apply(context);
        return context;
    }
}

/// <summary>
/// One step: <c>/Type</c> selects children of the context nodes, <c>//Type</c> children of the context
/// nodes and of all their descendants. Predicates filter each parent's children in turn, so <c>[n]</c>
/// counts among siblings that passed the earlier parts of the step.
/// </summary>
public sealed record XPathStep(bool AnyDepth, ControlType ControlType, IReadOnlyList<XPathPredicate> Predicates)
{
    public IReadOnlyList<UiNode> Apply(IReadOnlyList<UiNode> context)
    {
        var parents = AnyDepth ? context.SelectMany(node => node.DescendantsOrSelf()).Distinct() : context;
        var matches = new HashSet<UiNode>();
        foreach (var parent in parents)
        {
            IReadOnlyList<UiNode> candidates = parent.Children.Where(child => child.ControlType == ControlType).ToList();
            foreach (var predicate in Predicates) candidates = predicate.Filter(candidates);
            matches.UnionWith(candidates);
        }

        var ordered = matches.ToList();
        ordered.Sort(UiNode.CompareOrder);
        return ordered;
    }
}

public abstract record XPathPredicate
{
    public abstract IReadOnlyList<UiNode> Filter(IReadOnlyList<UiNode> siblings);
}

/// <summary><c>[n]</c>: the n-th (1-based) of the siblings.</summary>
public sealed record PositionPredicate(int Position) : XPathPredicate
{
    public override IReadOnlyList<UiNode> Filter(IReadOnlyList<UiNode> siblings) =>
        Position <= siblings.Count ? [siblings[Position - 1]] : [];
}

/// <summary><c>[condition]</c>: the siblings for which the condition holds.</summary>
public sealed record ConditionPredicate(XPathCondition Condition) : XPathPredicate
{
    public override IReadOnlyList<UiNode> Filter(IReadOnlyList<UiNode> siblings) =>
        siblings.Where(Condition.Test).ToList();
}

/// <summary>A boolean test on one node inside a predicate.</summary>
public abstract record XPathCondition
{
    public abstract bool Test(UiNode node);
}

/// <summary><c>@Attribute='value'</c>: exact, case-sensitive comparison.</summary>
public sealed record AttributeEquals(string Attribute, string Value) : XPathCondition
{
    public override bool Test(UiNode node) => node.Attribute(Attribute) == Value;
}

/// <summary><c>left and right</c>.</summary>
public sealed record And(XPathCondition Left, XPathCondition Right) : XPathCondition
{
    public override bool Test(UiNode node) => Left.Test(node) && Right.Test(node);
}

/// <summary><c>left or right</c>.</summary>
public sealed record Or(XPathCondition Left, XPathCondition Right) : XPathCondition
{
    public override bool Test(UiNode node) => Left.Test(node) || Right.Test(node);
}

/// <summary><c>contains(@Attribute, 'part')</c>: case-sensitive substring.</summary>
public sealed record Contains(string Attribute, string Value) : XPathCondition
{
    public override bool Test(UiNode node) => node.Attribute(Attribute)?.Contains(Value, StringComparison.Ordinal) == true;
}

/// <summary>
/// Recursive-descent parser of the supported XPath subset:
/// <code>
/// xpath      = step { step }
/// step       = ( "/" | "//" ) ControlType { "[" predicate "]" }
/// predicate  = integer | condition
/// condition  = and { "or" and }
/// and        = primary { "and" primary }
/// primary    = "(" condition ")" | "contains" "(" attribute "," literal ")" | comparison
/// comparison = attribute "=" literal
/// attribute  = "@" ( "AutomationId" | "Name" | "ClassName" )
/// literal    = "'" chars "'" | '"' chars '"'
/// </code>
/// Whitespace is allowed inside predicates.
/// </summary>
public static class XPathParser
{
    public const string AutomationId = "AutomationId";
    public const string Name = "Name";
    public const string ClassName = "ClassName";
    public static readonly IReadOnlyList<string> Attributes = [AutomationId, Name, ClassName];

    public static XPath Parse(string xpath) => new Parser(xpath).ParseXPath();

    /// <summary>The value as an xpath literal, or null when it holds both quote characters.</summary>
    public static string? Quote(string value) =>
        !value.Contains('\'') ? $"'{value}'"
        : !value.Contains('"') ? $"\"{value}\""
        : null;

    private sealed class Parser(string text)
    {
        private int position;

        public XPath ParseXPath()
        {
            if (!At('/')) throw Error("an xpath starts with / or //");
            var steps = new List<XPathStep>();
            while (position < text.Length) steps.Add(ParseStep());
            return new XPath(steps);
        }

        private XPathStep ParseStep()
        {
            Expect('/');
            var anyDepth = TryConsume('/');
            var controlType = ParseControlType();
            var predicates = new List<XPathPredicate>();
            while (TryConsume('['))
            {
                SkipWhitespace();
                predicates.Add(ParsePredicate());
                SkipWhitespace();
                Expect(']');
            }

            return new XPathStep(anyDepth, controlType, predicates);
        }

        private ControlType ParseControlType()
        {
            var start = position;
            var name = ReadName("a control type, e.g. Button");
            if (Enum.TryParse<ControlType>(name, ignoreCase: false, out var controlType)) return controlType;
            position = start;
            throw Error(Enum.TryParse(name, ignoreCase: true, out controlType)
                ? $"control types are case-sensitive; use '{controlType}'"
                : $"'{name}' is not a control type, e.g. Window, Button, Edit, MenuItem");
        }

        private XPathPredicate ParsePredicate()
        {
            if (!char.IsAsciiDigit(Current)) return new ConditionPredicate(ParseCondition());
            var start = position;
            while (char.IsAsciiDigit(Current)) position++;
            var index = int.TryParse(text.AsSpan(start, position - start), out var number) ? number : 0;
            if (index < 1)
            {
                position = start;
                throw Error("positions start at 1");
            }

            return new PositionPredicate(index);
        }

        private XPathCondition ParseCondition()
        {
            var condition = ParseAnd();
            while (TryKeyword("or")) condition = new Or(condition, ParseAnd());
            return condition;
        }

        private XPathCondition ParseAnd()
        {
            var condition = ParsePrimary();
            while (TryKeyword("and")) condition = new And(condition, ParsePrimary());
            return condition;
        }

        // Consumes the keyword and the whitespace around it, else leaves the position as it was.
        private bool TryKeyword(string keyword)
        {
            var start = position;
            SkipWhitespace();
            if (char.IsAsciiLetter(Current) && ReadName(keyword) == keyword)
            {
                SkipWhitespace();
                return true;
            }

            position = start;
            return false;
        }

        private XPathCondition ParsePrimary()
        {
            SkipWhitespace();
            if (TryConsume('('))
            {
                var inner = ParseCondition();
                SkipWhitespace();
                Expect(')');
                return inner;
            }

            if (!TryKeyword("contains")) return ParseComparison();
            Expect('(');
            SkipWhitespace();
            var attribute = ParseAttribute();
            SkipWhitespace();
            Expect(',');
            SkipWhitespace();
            var literal = ParseLiteral();
            SkipWhitespace();
            Expect(')');
            return new Contains(attribute, literal);
        }

        private XPathCondition ParseComparison()
        {
            var attribute = ParseAttribute();
            SkipWhitespace();
            Expect('=');
            SkipWhitespace();
            return new AttributeEquals(attribute, ParseLiteral());
        }

        private string ParseAttribute()
        {
            Expect('@');
            var start = position;
            var attribute = ReadName("an attribute name");
            if (!Attributes.Contains(attribute))
            {
                position = start;
                throw Error($"'@{attribute}' is not supported; use {string.Join(", ", Attributes.Select(a => "@" + a))}");
            }

            return attribute;
        }

        private string ParseLiteral()
        {
            if (!At('\'') && !At('"')) throw Error("expected a quoted string");
            var quote = text[position++];
            var end = text.IndexOf(quote, position);
            if (end < 0) throw Error($"missing closing {quote}");
            var value = text[position..end];
            position = end + 1;
            return value;
        }

        private string ReadName(string expected)
        {
            var start = position;
            if (char.IsAsciiLetter(Current))
                while (char.IsAsciiLetterOrDigit(Current)) position++;
            return position > start ? text[start..position] : throw Error($"expected {expected}");
        }

        private char Current => position < text.Length ? text[position] : '\0';

        private bool At(char c) => Current == c;

        private bool TryConsume(char c)
        {
            if (!At(c)) return false;
            position++;
            return true;
        }

        private void Expect(char c)
        {
            if (!TryConsume(c)) throw Error($"expected '{c}'");
        }

        private void SkipWhitespace()
        {
            while (char.IsWhiteSpace(Current)) position++;
        }

        private SpyError Error(string problem) =>
            new(ErrorCodes.InvalidRequest, $"Invalid xpath at character {position + 1}: {problem}.");
    }
}

/// <summary>The <c>states</c> a request may ask for and how each is read from an element.</summary>
public static class ElementState
{
    private static readonly Dictionary<string, Func<AutomationElement, JsonNode?>> Readers = new()
    {
        ["name"] = element => element.Properties.Name.ValueOrDefault,
        ["automationId"] = element => element.Properties.AutomationId.ValueOrDefault,
        ["controlType"] = element => element.Properties.ControlType.ValueOrDefault.ToString(),
        ["className"] = element => element.Properties.ClassName.ValueOrDefault,
        ["enabled"] = element => element.Properties.IsEnabled.ValueOrDefault,
        ["offscreen"] = element => element.Properties.IsOffscreen.ValueOrDefault,
        ["bounds"] = Bounds,
        ["value"] = element => element.Patterns.Value.PatternOrDefault?.Value.ValueOrDefault,
        ["toggle"] = Toggle,
        ["selected"] = element => element.Patterns.SelectionItem.PatternOrDefault is { } pattern ? pattern.IsSelected.ValueOrDefault : null,
        ["expanded"] = Expanded,
    };

    public static IReadOnlyCollection<string> Keys => Readers.Keys;

    /// <summary>The request's <paramref name="field"/>: null when absent; INVALID_REQUEST on an unknown key.</summary>
    public static IReadOnlyList<string>? Requested(Request request, string field = "states")
    {
        if (request.Array(field) is not { } items) return null;
        return items.Select((item, index) =>
            item is JsonValue value && value.TryGetValue(out string? key) && Readers.ContainsKey(key)
                ? key
                : throw new SpyError(
                    ErrorCodes.InvalidRequest,
                    $"'{field}[{index}]' must be one of: {string.Join(", ", Keys)}."))
            .ToList();
    }

    /// <summary>The requested keys of the element's state; null when none were requested.</summary>
    public static JsonObject? Read(AutomationElement element, IReadOnlyList<string>? states)
    {
        if (states is null || states.Count == 0) return null;
        var state = new JsonObject();
        foreach (var key in states.Distinct()) state[key] = Readers[key](element);
        return state;
    }

    private static JsonNode? Bounds(AutomationElement element)
    {
        var bounds = element.Properties.BoundingRectangle.ValueOrDefault;
        return bounds.IsEmpty
            ? null
            : new JsonObject { ["x"] = bounds.X, ["y"] = bounds.Y, ["width"] = bounds.Width, ["height"] = bounds.Height };
    }

    private static JsonNode? Toggle(AutomationElement element) =>
        element.Patterns.Toggle.PatternOrDefault?.ToggleState.ValueOrDefault switch
        {
            ToggleState.On => "on",
            ToggleState.Off => "off",
            ToggleState.Indeterminate => "indeterminate",
            _ => null,
        };

    private static JsonNode? Expanded(AutomationElement element) =>
        element.Patterns.ExpandCollapse.PatternOrDefault?.ExpandCollapseState.ValueOrDefault switch
        {
            ExpandCollapseState.Expanded or ExpandCollapseState.PartiallyExpanded => true,
            ExpandCollapseState.Collapsed => false,
            _ => null,
        };
}
