---
name: vertical-slice-architecture
description: Organise a codebase into vertical feature slices. Use when deciding what counts as a feature, naming or restructuring project folders, placing a new file, or judging whether a tree tracks capabilities or technical layers.
---

# Vertical Slice Architecture

Cut the tree by **capability**, not by technical kind. A folder earns its name by stating something the user can do; everything that serves that capability — its UI, its logic, its data shapes — lives inside it, because those files change together for the same reason.

## Glossary

Use these terms exactly — the whole point is that "feature" stops being a synonym for "screen" or "folder".

**Feature** — a capability the application offers a user, together with all the code that delivers it. Named as a capability, sized by what changes together. The unit this skill cuts by.

**Slice** — the vertical shape a feature takes in the tree: UI, logic and data for one capability standing side by side, cutting *across* the technical layers rather than sitting in one of them.

**Layer** — a technical kind of thing (components, services, models, controllers). Layers survive as folders *inside* a slice, never as the tree's top level.

**Composition root** — an artifact whose whole job is to arrange pieces owned by others: a page, a screen, a route handler, a screen's layout. It holds arrangement, not capability.

**Shared** — code that more than one feature depends on, promoted out of every feature so no feature owns it. The tree's other half, deliberately small.

## The three tests

Apply all three to a candidate. A capability that passes all three is a feature; one that fails any is a fragment of one, or several wearing one name.

1. **Value** — can you finish the sentence "the user can ___"? *The user can browse and select tests*, *the user can start a run and watch it*. A name that resists the sentence (`Utils`, `Dashboard`, `Manager`) is naming a bag, not a capability.
2. **Cohesion** — do these files change *together*, for the same business reason? Trace a realistic change request: if it lands inside one folder, the cut holds; if it fans out across several, the cut is wrong.
3. **Coupling** — can you describe and test the capability without knowing the insides of the others? A slice you can only explain by reciting a neighbour's internals is not yet separate.

## Disambiguation

Three artifacts get mistaken for features. Each has its own home:

| Artifact | What it actually is | Where it goes |
| --- | --- | --- |
| **Page / screen** | A composition root: a piece of UI at a URL that arranges components from *several* features | Outside the slices, in the app shell (`Pages/`, `Routes/`) |
| **Layer** | A technical kind — services, models, components | A folder *inside* a slice |
| **Entity** | A data shape | Inside the feature that owns its behaviour; in `Shared` only once a second feature genuinely needs it |

**Pages and features are many-to-many.** One page hosts several features; one feature can appear on several pages. A tool with two screens can hold six features, and a tool with twenty pages can hold three. Count capabilities, never screens.

## Layout

```
Features/
  <Capability>/          # named "the user can <capability>"
    Components/          # UI this capability owns
    Services/            # logic this capability owns
    Models/              # data shapes this capability owns
Pages/                   # composition roots, thin: arrangement only
Shared/                  # cross-feature code, small by design
```

A feature owns everything only it uses. The moment a *second* feature needs a piece, promote it to `Shared` — and treat each promotion as evidence: several promotions in a row out of the same pair of slices means the pair is really one feature.

Keep composition roots thin. A page that grows logic of its own has started hoarding a capability that belongs in a slice.

## Sizing

Miscut shows up as traffic between folders, so read the traffic:

- **Too coarse** — one folder absorbs unrelated change requests, and two developers touching different business concerns collide in it. Split along the change reasons.
- **Too fine** — every change request touches three slices at once, or one slice reaches constantly into another's internals. Merge them: they were one capability wearing two names.
- **Layer in disguise** — a slice holding only one technical kind (`Models/` at the top level, a feature that is nothing but services). Fold it into the capability it serves.

## Placing work

When adding a file or restructuring a tree, name the capability first, then place the code:

1. State the capability as "the user can ___". If the sentence resists, you have a composition root or shared code, not a feature.
2. Run cohesion and coupling against the existing slices — an existing feature usually already owns the change.
3. Place the file in that slice's layer folder; put arrangement in a composition root and cross-feature code in `Shared`.
4. Check the result: every file sits in exactly one slice, one composition root, or `Shared`, and every slice name passes the value test.

Step 4 is the bar for a finished restructure — walk the whole tree against it, not a sample.

## Recording the cut

The feature list *is* an architectural decision: which capabilities exist, and why the boundaries fall where they do. When the cut is made or changed, write it down where the project keeps decisions (an ADR, `CONTEXT.md`) so the next change argues with a recorded boundary instead of guessing one.
