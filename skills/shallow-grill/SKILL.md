---
name: shallow-grill
description: A shallow-planning interview to settle a plan or design.
disable-model-invocation: true
---

Run a `/grilling` session as **shallow planning**. Where the two differ, shallow planning wins: it
decides which questions to ask and ends the session once no blocking question remains. Grilling
supplies the rest — rounds, question format, recommended answers, fact-finding through sub-agents.

Use the definition of Shallow planning already in your context. When your context holds none, use
this one:

> Planning kept to the fewest rounds that settle the work — ideally one, two when needed, more only exceptionally. User is asked only the blocking questions (those the agent cannot resolve itself and where a wrong guess would derail the work); agent decides everything else by itself. Agent opens another round only when answers raise new blocking questions, or when the user points out uncertainties or asks questions.

When the `grilling` skill is missing or cannot be invoked, tell the user and stop.
