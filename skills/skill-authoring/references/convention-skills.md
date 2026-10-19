# Convention skills

A convention skill holds rules the agent returns to on demand while it works, e.g. the conventions
of a language or an architecture.

## Shape

- **Purpose** — open the body with one sentence stating why the rules exist.
- **`## Rules`** — what the agent must do, every time. A guardrail — a hard prohibition — is a rule too, paired with the behaviour to take instead.
- **`## Guidelines`** — judgement calls the agent weighs against the situation at hand.

Sort each convention as the user frames it: a requirement goes under Rules, a judgement call under Guidelines, even when its wording reads like a rule. When the user leaves it open, it is a rule only if the agent must follow it in every case.

Both chapters are optional; leave out a chapter that would be empty. When a skill has neither rules nor guidelines, tell the user it may not be a convention skill, so they can reconsider its type.

## Examples

Show a rule or guideline by example in this fixed form: ❌ with the reason and a sample, then ✅ with a sample.

````markdown
❌ <Why the sample breaks the rule.>

```<language>
<sample>
```

✅

```<language>
<sample>
```
````

## Description

A convention skill is usually implicit, so its description is all the agent sees when it decides whether the rules apply. Describe the situations it applies to more fully than a hybrid skill's literal trigger: name every distinct kind of task the rules touch, one trigger each, e.g. `Use when writing, reviewing or refactoring C# code — classes, constructors, method calls, file and namespace layout.`
