import { existsSync, readdirSync } from "node:fs";
import { join, relative } from "node:path";
import { pathToFileURL } from "node:url";
import { afterAll, beforeAll, expect, it } from "vitest";
import { copilotAccountEnv, readConfig } from "./account.ts";
import { EvalsReport } from "./report.ts";
import { findWaza, runEval } from "./waza.ts";

// Sets up a test file running the waza evals (tests/evals/<eval>/eval.yaml) of one scope; evals of
// in-progress content live in tests/evals/in-progress/. Test files list each eval by name, so the
// VS Code Test Explorer, which finds tests by reading the source, shows them before a run.
export function useEvals(scope: "shipped" | "in-progress") {
  const repoRoot = join(import.meta.dirname, "..", "..");
  const evalsDir = join(repoRoot, "tests", "evals", ...(scope === "in-progress" ? ["in-progress"] : []));
  const model = process.env.EVAL_MODEL || "claude-sonnet-5.5";
  const report = new EvalsReport(repoRoot, scope, model);
  const declared: string[] = [];
  let waza: string;
  let env: Record<string, string>;

  beforeAll(() => {
    waza = findWaza();
    env = copilotAccountEnv(readConfig(repoRoot));
  });

  afterAll(() => {
    if (!report.isEmpty) console.log(`Report: ${report.write()}`);
  });

  return {
    // Runs the eval tests/evals/[in-progress/]<name> as one test.
    evalTest(name: string) {
      declared.push(name);
      it(name, async () => {
        const outcome = await runEval({
          waza,
          evalDir: join(evalsDir, name),
          outDir: join(report.runDir, name),
          model,
          repoRoot,
          env,
        });
        report.add(name, outcome);
        const reportLink = pathToFileURL(join(report.runDir, name, "console.txt")).href;
        const verdict = outcome.exitCode === 0 ? "PASS" : `FAIL (waza exit ${outcome.exitCode})`;
        // Logged inside the test so VS Code Test Results shows it under this eval.
        console.log(`Eval ${name}: ${verdict}\nReport: ${reportLink}`);
        if (outcome.exitCode !== 0)
          expect.fail(`Eval '${name}' failed (waza exit ${outcome.exitCode}). Report: ${reportLink}`);
      });
    },
    // Fails when the evalTest calls and the eval folders differ, so no eval is left out.
    expectAllEvalsDeclared() {
      const found = readdirSync(evalsDir, { withFileTypes: true })
        .filter((entry) => entry.isDirectory() && existsSync(join(evalsDir, entry.name, "eval.yaml")))
        .map((entry) => entry.name);
      const dir = relative(repoRoot, evalsDir).replaceAll("\\", "/");
      expect([...declared].sort(), `Eval test list does not match the evals in '${dir}'`).toEqual(found.sort());
    },
  };
}
