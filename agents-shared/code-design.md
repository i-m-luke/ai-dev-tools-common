# Code design

Apply these rules by default when designing or writing code. Depart from one only when a language or framework forces it (e.g. a framework requires classes with behaviour), and tell the user which rule you departed from and why.

## Functional core, imperative shell

Split code into two layers:

- **Core** — all logic and decisions, as pure functions over immutable data; no I/O, no dependencies.
- **Shell** — a thin layer without logic; does the I/O, holds the state, and calls the core.

## Choosing a paradigm

The closer code sits to data, the more functional it is; the closer to the UI, the more object-oriented it may be.

- **Backend** — data flows from an endpoint to storage or another endpoint and back through a function call chain. Data objects carry no behaviour; I/O adapters (database, HTTP clients) may be objects with behaviour, as part of the shell.
- **Frontend** — use an object for state that lives over time and has identity (component, view model, store). The object owns its state and changes it only through its methods, delegating the logic (validation, derived state, state transitions) to pure functions.

## Pure functions

A function is **pure** when it meets both rules:

1. **Deterministic** — its result depends only on its arguments. Pass hidden inputs (current time, random values, environment, mutable global state) in as arguments.
2. **No side effects** — returning a value is its only effect. A **side effect** is any observable interaction beyond the return value: writing to a database, file, network, console or UI, or mutating arguments or state outside the function.

Both rules imply:

- **Immutability** — return new data instead of changing the input; mutating a value created inside the function keeps it pure.
- **Contagion** — calling an impure function makes the caller impure.

Test purity by **referential transparency**: replacing a call with its result leaves the program's behaviour unchanged. `add(2, 3)` can become `5`; `saveUser(user)` cannot become `true`, because the write would be lost.

Logging is tolerated inside pure functions.

## Impure functions

Impure functions carry the side effects an application needs: storage, network, the user. Place them at the edges of a function call chain, where they open and close it, and keep them thin:

```text
pipe(
  readDataFromFile,   // impure: opens the chain
  fn1,
  fn2,
  fn3,
  saveDataToDb)       // impure: closes the chain
```

When the chain needs I/O midway, split it into consecutive sandwiches: impure → pure → impure → pure → impure.

## Errors

Prefer **errors as values** for expected failures (invalid input, not found, rejected request) where the language or project already offers an idiomatic way; elsewhere throw. Unexpected failures (bugs, unrecoverable states) throw.
