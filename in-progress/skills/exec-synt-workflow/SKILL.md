---
name: exec-synt-workflow
description: Use ONLY when the literal text "/exec-synt-workflow" or a `workflow` code block appears in the request or instructions — never otherwise, whatever the task.
---

Execute a workflow written in a fenced code block tagged `workflow`, step by step, exactly as written. It runs when invoked or run as `/exec-synt-workflow`, or when the instructions you follow (e.g. another skill) contain such a block. Code or pseudocode merely discussed, in a block with another tag or none, is not a workflow. The blocks in this file are illustrations of the syntax, tagged `text`: never execute them.

A workflow may span several messages; keep executing it where it left off.

# Syntax

## Steps

One step per line, run top to bottom. A step is either a quoted text or a free-text instruction.

## Nesting

Indentation (4 spaces) nests steps under the `if`, `else` or `while` line above them. A nested step belongs to the nearest less-indented `if`, `else` or `while` line. Branches and loops nest within each other to any depth.

## Branching

```text
if (condition in natural language):
    steps run when the condition holds
else:
    steps run when it does not
```

`else:` is optional and pairs with the `if` at the same indentation directly above it. Evaluate the condition from what is known in the conversation, then run only the chosen branch's steps and none of the other.

## Loops

```text
while (condition in natural language):
    steps repeated while the condition holds
```

Evaluate the condition before every iteration, from what is known at that moment. When it holds, run the nested steps in order, then evaluate it again; when it does not, skip the nested steps and continue with the step after the loop. If it does not hold on the first evaluation, the nested steps run zero times. There is no `else:` for a loop.

Infinite-loop guard: if nothing the condition depends on (a user reply, a task result, a value the steps change) could have changed during an iteration, the loop would never end. End the whole workflow like `Stop("reason")`, telling the user that the loop could not end and why.

## Tasks and Stop

Reusable steps are defined as tasks under a `# TASKS` heading at the end of the block, one definition per `Name(params): body`. A task is called like a method, `Name(args)`, on a line of its own; the call runs the task's body in place, then the flow continues after the call. In the body, `{param}` stands for the argument passed for `param`.

```text
AskUser("What would you like?")

# TASKS
AskUser(question): Ask "{question}"
Greet(name):
    Say "Hello {name}"
    AskUser("How are you?")
```

A task body is either a one-line description after the colon, or an indented multi-line workflow below the definition line (`:` then nothing) with the same syntax as the main flow, which may call other tasks. Tasks have no return values.

`Stop()` and `Stop("reason")` are built in. They end the whole workflow at once, from anywhere, including inside a task: run no further step, neither in the task nor in the main flow. `Stop("reason")` also tells the user the reason, verbatim; a bare `Stop()` outputs nothing.

# Execution rules

- Run the control flow exactly as written. Never add, skip, repeat (other than as a `while` loop dictates) or reorder steps.
- Say a quoted text verbatim: the characters between the quotes, unchanged and untranslated. A step that only quotes a text, or says it (e.g. `Say "…"`), outputs just that text.
- Perform any other step by its meaning.

# Unknown values

Never guess a value. When a condition depends on a value you do not know from the conversation, ask the user for it, run no further step, and wait for the answer. Then continue the workflow from the same point.

A workflow often spans several messages: whenever a step needs the user's reaction, end your message there and resume with the next step once the user replies.

# Output

Output only what the workflow's steps prescribe. Do not narrate the execution: no mention of conditions evaluated, branches taken or steps run, and no intro or recap. Show the execution trace or diagnostics only on an error or a `Stop("reason")`, to explain why the execution ended, and never quote a step that did not run; a bare `Stop()` outputs nothing.

# Validation

Before the first step, check the whole workflow, including the `# TASKS` section:

- Syntax: every construct is well formed (e.g. `if (…):` and `while (…):` with parentheses and a colon, consistent indentation, task definitions as `Name(params): body`).
- Undefined tasks: every call `Name(args)`, other than `Stop`, refers to a defined task.
- Argument count: every call passes exactly as many arguments as the task has parameters.

On any error, report it to the user and do not start: execute no step, not even the ones before the error. Never guess what the author meant.
