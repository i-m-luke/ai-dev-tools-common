# Design visualization

Show each part the plan shapes, new or existing; draw **Sequence** and **Flow** only when they answer a question the plan text leaves open:

- **Model** — use when the plan shapes data; draw the shape of data alone. Put each property on its own line with its type. Draw a nested type inline when only one type uses it; otherwise draw it separately and reference it by name:

  ```text
  Building {
    color: "red" | "green" | "blue",
    adress: string,
    dimension: Dimension {
      height: int,
      width: int,
    },
    walls: many of Wall { ... },
  }
  ```

- **API** — use when the plan shapes a public contract; each type's properties and method signatures as text, drawn as members in the Relations diagram only when the user asks for it.

  ```text
  class OrderService
    + Orders: IReadOnlyList<Order>
    + Place(order: Order): Result<OrderId>
  ```

- **Relations** — use when the plan shapes how types relate; a Mermaid `classDiagram` of type names and their links, without members.
- **Sequence** — use when several parts collaborate and the order of their calls or messages matters (e.g. async); a Mermaid `sequenceDiagram`.
- **Flow** — use when logic branches or data passes through steps; a Mermaid `flowchart`.
