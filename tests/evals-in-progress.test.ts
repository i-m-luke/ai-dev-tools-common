import { it } from "vitest";
import { useEvals } from "./evals-executor/eval-test.ts";

// Evals of in-progress content, one evalTest per folder in tests/evals/in-progress/. Names are listed
// by hand so the VS Code Test Explorer shows them; the last test catches a folder added or removed
// without updating this list.
const { evalTest } = useEvals("in-progress");

evalTest("exec-synt-workflow");
