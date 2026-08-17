# README

This README is for whoever **edits** the skill (human or agent): `SKILL.md` does not point here, so this
file never loads into the consuming agent's context — it rides only on the editor's attention.

## Editing guidelines

### Keep disambiguation positive

The skill distinguishes a feature from a page, a layer and an entity. That material is written as the
positive **Disambiguation** table — what each artifact *is* and where it *goes* — never as a list of
"a feature is not a ...".

Steering by prohibition drags the forbidden concept into context and makes it more available, so a
"not a page" framing half-reads as permission to slice by page. The table does the same separating
work while attention lands on the correct home. Keep any future distinctions in that shape.

### Keep the skill stack-agnostic

The slicing rules hold for any language, framework or platform. The `Layout` section uses generic
folder names for that reason; no framework-named examples, no stack-specific vocabulary.

### Model invocation is deliberate

Unlike `document-app`, this skill omits `disable-model-invocation`, so the agent can fire it on its
own and other skills can reach it. That is the point — placement decisions happen mid-task, when the
agent is already writing code and nobody is there to invoke a skill by hand. It costs permanent
context load for the description; that trade is intentional.

### Name

Named for the pretrained term (Jimmy Bogard's *vertical slice architecture*) so the title, the
glossary term `slice` and everyday prompts share one word. The earlier name
`feature-based-project-system` was dropped: "project system" is taken in the .NET tooling world
(Visual Studio's Common Project System) and recruited the wrong priors.
