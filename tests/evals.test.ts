import { it } from "vitest";
import { useEvals } from "./evals-executor/eval-test.ts";

// Evals of shipped (shipped) content, one evalTest per folder in tests/evals/; evals of in-progress
// content are in evals-in-progress.test.ts. Names are listed by hand so the VS Code Test Explorer
// shows them; the last test catches a folder added or removed without updating this list.
const { evalTest, expectAllEvalsDeclared } = useEvals("shipped");

evalTest("agents-shared");
evalTest("document-app");
evalTest("help-with-writing");
evalTest("manage-github-issues");
evalTest("notify");
evalTest("roles");
evalTest("shallow-grill");
evalTest("skill-authoring");
evalTest("sync-app-doc");
evalTest("vertical-slice-architecture");
evalTest("write-app-doc");

it("eval test list matches the eval folders", expectAllEvalsDeclared);
