---
name: shallow-grill
description: A shallow-planning interview to settle a plan or design.
disable-model-invocation: true
---

Run a `/grilling` session as **shallow planning**. When the `grilling` skill's instructions conflict
with the Shallow planning definition, the definition wins.

When your context holds an explicit definition of the term "Shallow planning" (e.g. contained in a glossary), use it and ignore the fallback. Otherwise use this fallback:

> Planning kept to the fewest rounds that settle the work — ideally one, two when needed, more only exceptionally. User is asked only the blocking questions (those the agent cannot resolve itself and where a wrong guess would derail the work); agent decides everything else by itself. Agent opens another round only when answers raise new blocking questions, or when the user points out uncertainties or asks questions.

When the `grilling` skill is missing or cannot be invoked, tell the user and stop.
