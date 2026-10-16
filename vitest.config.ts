import { defineConfig } from 'vitest/config';

const minute = 60_000;

export default defineConfig({
  test: {
    reporters: ['default', './tests/no-tests-run-reporter.ts'],
    projects: [
      {
        test: {
          name: 'script-tests',
          include: ['tests/script-tests.test.ts'],
          testTimeout: 30 * minute,
        },
      },
      {
        test: {
          name: 'evals',
          include: ['tests/evals.test.ts'],
          testTimeout: 180 * minute,
          hookTimeout: minute,
        },
      },
      {
        test: {
          name: 'evals-in-progress',
          include: ['tests/evals-in-progress.test.ts'],
          testTimeout: 180 * minute,
          hookTimeout: minute,
        },
      },
    ],
  },
});
