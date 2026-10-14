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

# Execution rules

- Run the control flow exactly as written. Never add, skip, repeat or reorder steps.
- Say a quoted text verbatim: the characters between the quotes, unchanged and untranslated. A step that only quotes a text, or says it (e.g. `Say "…"`), outputs just that text.
- Perform any other step by its meaning.

# Output

Output only what the workflow's steps prescribe. Do not narrate the execution: no mention of conditions evaluated, branches taken or steps run, and no intro or recap.
