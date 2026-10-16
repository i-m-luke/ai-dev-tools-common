import type { Reporter, TestModule } from 'vitest/node';

// Fails a run in which no test ran, so a mistyped `-t` filter never passes as success.
export default class NoTestsRunReporter implements Reporter {
  onTestRunEnd(testModules: ReadonlyArray<TestModule>) {
    const ran = testModules.some((module) =>
      [...module.children.allTests()].some((test) => test.result().state !== 'skipped'),
    );
    if (ran) return;
    console.error('No test ran; check the -t filter.');
    process.exitCode = 1;
  }
}
