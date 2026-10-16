# Workflow skills

A workflow skill walks the agent through ordered steps towards a goal. A tool skill — one built
around scripts — is a workflow skill too; its scripts follow `references/scripts.md`.

## Shape

- **Goal** — open the body with one sentence stating what the steps lead to.
- **Initialization** — optionally, put what must hold before the work towards the goal starts —
  checking prerequisites or the environment, loading a called skill, creating the artifacts folder —
  under an `## Initialization` chapter right before `## Steps`. The agent runs it once, at the start
  of the skill. Its steps follow the rules of `## Steps`, numbered from 1 on their own; a single
  initialization step may stay a paragraph without a chapter. Refer to them as "initialization step
  N".
- **Steps** — put the steps under a `## Steps` chapter, so the sequence stands apart from the
  reference it consults. Each step is a chapter of its own, `### N. <action>`, numbered from 1 and
  named by what the agent does.
- **Completion condition** — end every step, initialization ones included, with the condition that
  tells the agent the step is done, e.g. "Done when every changed file is listed."
- **Decisions** — express every decision as a playbook: one `<outcome>` — `<action>` item per
  outcome, ending with `*` for any other outcome.
- **Close** — optionally end with a step that reports the results to the user, linking every file
  the skill created or changed.

## Reference

- Reference used by a single step, such as its playbook, lives inside that step.
- Reference shared by several steps gets a chapter beside `## Steps`.
- What a script returns and which errors it reports lives in the script's help, never in the skill:
  the skill names the command that prints the help, so the two cannot drift apart.

## Loops

Send the agent back to an earlier step only in this form, so every loop ends:

> Go back to step `<N>` while `<condition>` — at most `<M>` times, or until a round leaves the
> result unchanged; then `<action>`.

`<action>` says what the agent does once the loop stops, e.g. "then show the user what still fails
and stop".

A loop stays within its chapter: a step never sends the agent back to initialization. When
initialization fails, its playbook stops the skill or tells the user what to do first.

## Skeleton

````markdown
<One sentence stating the goal.>

## Initialization

### 1. <Action>

Run `<exact command>`. Act on the script's exit code by this playbook:

- `0` — continue.
- `*` — show the user the script's stderr and stop.

## Steps

### 1. <Action>

<What the agent does.> Done when <condition>.

### 2. <Action>

Run `<exact command>`. Act on the script's exit code by this playbook:

- `0` — <action>.
- `2` — <action>.
- `*` — show the user the script's stderr and stop.

### 3. Report

Tell the user what changed, linking every file the skill created or changed. Done when the user has
the report.

## <Reference shared by several steps>
````
