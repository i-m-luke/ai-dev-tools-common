# Interview

Settle a new skill's specification with the user in two rounds — the base specification, then its details — before writing any of the skill's files.

When the user tells you to decide on your own, answer every question yourself, ask the user nothing, and report the specification and every conflict the [consistency check](#consistency-check) found together with the finished skill.

## Steps

### 1. Settle the base specification

Answer these questions in this order, from the user's request and what you know of the workspace:

1. **Purpose** — what problem the skill solves and what result it delivers, in one sentence.
2. **Type** — the skill type that fits its primary purpose.
3. **Category** — the category that fits who invokes the skill — the user by hand, the agent on its own, or other skills — starting from the type's usual category.

Derive the skill's name and description from its category, and run the [consistency check](#consistency-check) on the answers.

Show the user everything in one message, as a numbered list in the order above followed by the name and the description: give each item your proposed answer with a one-line reason, mark the items you cannot answer yourself as questions, and list every conflict the check found below. Done when the user has confirmed or corrected every item and every conflict is resolved; the result is the base specification — purpose, type, category, name and description.

### 2. Settle the details

Run `/grilling` skill (authored by Matt Pocock) on the base specification, to settle the details its requirements raise — e.g. the skill's inputs and outputs, which steps run as scripts and in which language, and which skills it calls, as required or optional. When the `grilling` skill is missing or cannot be invoked, tell the user and continue without it. Where its instructions conflict with this skill's, this skill's win.

Done when every question the interview raised is answered.

### 3. Check the whole specification

Run the [consistency check](#consistency-check) on the base specification together with its details, and show the user every conflict it finds in one message. Done when every conflict is resolved.

## Consistency check

Compare the answers with each other and with the rules of `SKILL.md`; each pair below that disagrees is a conflict:

- **Type and category** — the category differs from the type's usual one, and no answer gives the reason.
- **Category and name** — the name takes the form the category prescribes.
- **Category and description** — the description starts and reads as the category prescribes.
- **Purpose and type** — the purpose holds one primary purpose; two substantial purposes of different types call for splitting the skill.
- **Details and base specification** — every detail fits the purpose, type and category, e.g. a skill other skills must call cannot be explicit.

Present each conflict by naming the answers that clash and proposing how to resolve it.
