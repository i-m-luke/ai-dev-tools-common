# Design visualization

Draw a view for each aspect the plan shapes, new or existing; the sections below pair each aspect with its view. Skip the preamble and keep prose brief. Pick the smallest view that makes the key point clear.

## Structure

For files or folders, show a diff tree of the touched ones, plus only the context needed to place them:

```diff
 src/
  Orders/
+   Order.cs          (new: order record)
+   OrderService.cs   (new: places orders)
-   OrderRepository.cs   (delete: deprecated)
~ Program.cs          (edit: registers OrderService)
```

## Model

For data, show its shape alone. Put each property on its own line with its type. Draw a nested type inline when only one type uses it; otherwise draw it separately and reference it by name:

```pseudocode
Building {
  color: "red" | "green" | "blue",
  address: string,
  dimension: Dimension {
    height: int,
    width: int,
  },
  walls: many of Wall { ... },
}
```

## API

For a public contract, show each type's properties and method signatures as text.

```pseudocode
class OrderService
  Orders: IReadOnlyList<Order>
  Place(order: Order): Result<OrderId>
```

## Relations

For how types relate, show a Mermaid `classDiagram` of type names and their links, without members unless the user asks for them.

## Sequence

When several parts collaborate and the order of their calls or messages matters (e.g. async), show a Mermaid `sequenceDiagram`.

## Flow

When logic branches or transforms data step by step, show it in one of two forms.

Within one function, show pseudocode:

```pseudocode
on(save)
  ...
```

Across functions, show a Mermaid `flowchart`.
