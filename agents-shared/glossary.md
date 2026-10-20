# Glossary

- **Explicit skill** — a skill with model invocation turned off (e.g. `disable-model-invocation: true`), so only a user calling it by name runs it.
- **Implicit skill** — any skill that is not explicit; the model may invoke it on its own.
- **Planning** — any questioning of the user before or during work to settle how to proceed: design discussion, clarifying requirements, reviewing a plan or idea.
- **Playbook** — a list of key–action pairs, each binding an outcome (e.g. an app's error code, a step's result, a user's answer) to the action to take when it occurs.
- **Shallow planning** — planning kept to the fewest rounds that settle the work: ideally one, two when needed, more only exceptionally. Only blocking questions are asked (ones you cannot resolve yourself and where a wrong guess would derail the work); decide everything else yourself. Another round is opened only when answers raise new blocking questions, or the user points out uncertainties or asks questions.
- **Specification** — the approved plan, with its confirmed design visuals, if exists any.
- **Summary commit** — a branch squashed into one commit: its whole diff against the merge target, leaving that commit as the branch's only one. Its title sums up the essence of the change; the body adds only the necessary details.
