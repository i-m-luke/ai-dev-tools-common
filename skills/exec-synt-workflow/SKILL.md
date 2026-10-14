---
name: exec-synt-workflow
description: Use when ordered to execute a workflow, or when following instructions that contain a `workflow` code block.
---

Execute a workflow written in a fenced code block tagged `workflow`, step by step, exactly as written. It runs when the user orders it, or when the instructions you follow (e.g. another skill) contain such a block. Code or pseudocode merely discussed, in a block with another tag or none, is not a workflow.

A workflow may span several messages; keep executing it where it left off.

# Syntax

## Steps

One step per line, run top to bottom. A step is either a quoted text or a free-text instruction.

## Nesting

Indentation (4 spaces) nests steps under the `if` or `else` line above them. A nested step belongs to the nearest less-indented `if` or `else` line.

## Branching

```workflow
if (condition in natural language):
    steps run when the condition holds
else:
    steps run when it does not
```

`else:` is optional and pairs with the `if` at the same indentation directly above it. Evaluate the condition from what is known in the conversation, then run only the chosen branch's steps and none of the other.

## Tasks and Stop

Reusable steps are defined as tasks under a `# TASKS` heading at the end of the block, one definition per `Name(params): body`. A task is called like a method, `Name(args)`, on a line of its own; the call runs the task's body in place, then the flow continues after the call. In the body, `{param}` stands for the argument passed for `param`.

```workflow
ZeptejSe("Co si přejete?")

# TASKS
ZeptejSe(otázka): Zeptej se "{otázka}"
Pozdrav(jméno):
    Řekni "Ahoj {jméno}"
    ZeptejSe("Jak se máš?")
```

A task body is either a one-line description after the colon, or an indented multi-line workflow below the definition line (`:` then nothing) with the same syntax as the main flow, which may call other tasks. Tasks have no return values.

`Stop()` and `Stop("reason")` are built in. They end the whole workflow at once, from anywhere, including inside a task: run no further step, neither in the task nor in the main flow. `Stop("reason")` also tells the user the reason, verbatim; `Stop()` ends silently.

# Execution rules

- Run the control flow exactly as written. Never add, skip, repeat or reorder steps.
- Say a quoted text verbatim: the characters between the quotes, unchanged and untranslated. A step that only quotes a text, or says it (e.g. `Say "…"`), outputs just that text.
- Perform any other step by its meaning.

# Output

Output only what the workflow's steps prescribe. Do not narrate the execution: no mention of conditions evaluated, branches taken or steps run, and no intro or recap. Show the execution trace or diagnostics only on an error or a `Stop`, to explain why the execution ended.

# Validation

Before the first step, check the whole workflow, including the `# TASKS` section:

- Syntax: every construct is well formed (e.g. `if (…):` with parentheses and a colon, consistent indentation, task definitions as `Name(params): body`).
- Undefined tasks: every call `Name(args)`, other than `Stop`, refers to a defined task.
- Argument count: every call passes exactly as many arguments as the task has parameters.

On any error, report it to the user and do not start: execute no step, not even the ones before the error. Never guess what the author meant.
