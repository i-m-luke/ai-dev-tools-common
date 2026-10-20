# Design visualization

Show each part the plan shapes, new or existing; draw **Structure** first, and **Sequence** and **Flow** only when they answer a question the plan text leaves open:

- **Structure** — use when the plan touches files or folders; draw the tree of the folders and files the plan touches, plus only the context needed to place them. Indent each child two spaces under its folder and end folder names with `/`. Give each entry a brief note in parentheses, aligned in one column, saying what it is and, when it helps, how the plan touches it:

  ```text
  src/                  (application code)
    Orders/             (new feature slice for orders)
      Order.cs          (new; order record)
      OrderService.cs   (new; places orders)
    Program.cs          (registers OrderService)
  ```

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
