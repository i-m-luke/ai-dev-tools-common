import { defineConfig } from "vitest/config";

const minute = 60_000;

export default defineConfig({
  test: {
    reporters: ["default", "./tests/no-tests-run-reporter.ts"],
    projects: [
      {
        test: {
          name: "repo-checks",
          include: ["tests/repo-checks.test.ts"],
          testTimeout: 5 * minute,
        },
      },
      {
        test: {
          name: "script-tests",
          include: ["tests/script-tests.test.ts"],
          testTimeout: 30 * minute,
        },
      },
      {
        test: {
          name: "[WARNING: Cost tokens] evals",
          include: ["tests/evals.test.ts"],
          testTimeout: 180 * minute,
          hookTimeout: minute,
        },
      },
      {
        test: {
          name: "[WARNING: Cost tokens] evals-in-progress",
          include: ["tests/evals-in-progress.test.ts"],
          testTimeout: 180 * minute,
          hookTimeout: minute,
        },
      },
    ],
  },
});
