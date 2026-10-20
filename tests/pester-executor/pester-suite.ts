import { spawn } from 'node:child_process';
import { mkdtempSync, readdirSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, relative } from 'node:path';
import { expect, it } from 'vitest';

// Runs Pester files (`*.Tests.ps1`) under a folder in tests/ as Vitest tests.
const repoRoot = join(import.meta.dirname, '..', '..');

const pesterScript = `
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
Import-Module Pester -MinimumVersion 5.0
$config = New-PesterConfiguration
$config.Run.Path = $env:PESTER_TEST_FILE
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'
$config.Output.RenderMode = 'Plaintext'
$result = Invoke-Pester -Configuration $config
function Get-Reason($Item) {
    $message = $Item.ErrorRecord | Select-Object -First 1 | ForEach-Object { $_.Exception.Message }
    $message ? ": $(($message -split '\\r?\\n')[0])" : ''
}
$failures = @(
    $result.Failed | ForEach-Object { "$($_.ExpandedPath)$(Get-Reason $_)" }
    $result.FailedBlocks | ForEach-Object { "$($_.ExpandedPath)$(Get-Reason $_)" }
    $result.FailedContainers | ForEach-Object { "$($_.Item)$(Get-Reason $_)" }
)
ConvertTo-Json -InputObject $failures | Set-Content -LiteralPath $env:PESTER_FAILURES_FILE -Encoding utf8
`;

export interface PesterSuite {
  // Runs the Pester file <dir>/<file> as one test, in its own pwsh process.
  test(file: string): void;
  // Like test(); when it fails, the test() calls declared after it are skipped.
  prerequisite(file: string): void;
  // Fails when the declared files and the Pester files in <dir> differ, so no file is left out.
  expectAllFilesDeclared(): void;
}

// Test files list each Pester file by name so the VS Code Test Explorer, which finds tests by
// reading the source, shows them before a run.
export function pesterSuite(dir: string): PesterSuite {
  const root = join(repoRoot, 'tests', dir);
  const declared: string[] = [];
  const failedPrerequisites: string[] = [];

  return {
    test(file) {
      declared.push(file);
      it(testName(file), async (context) => {
        if (failedPrerequisites.length) {
          context.skip(`prerequisites failed (${failedPrerequisites.join(', ')}); fix them first`);
        }
        await expectPesterPasses(join(root, file));
      });
    },
    prerequisite(file) {
      declared.push(file);
      it(testName(file), async () => {
        try {
          await expectPesterPasses(join(root, file));
        } catch (error) {
          failedPrerequisites.push(file);
          throw error;
        }
      });
    },
    expectAllFilesDeclared() {
      const found = readdirSync(root, { recursive: true, encoding: 'utf8' })
        .filter((file) => file.endsWith('.Tests.ps1'))
        .map((file) => file.replaceAll('\\', '/'));
      const shown = relative(repoRoot, root).replaceAll('\\', '/');
      expect([...declared].sort(), `Test list does not match the Pester files in '${shown}'`).toEqual(found.sort());
    },
  };
}

// The enclosing describe() names the skill folder, so the test shows only the file name.
function testName(file: string): string {
  return file.slice(file.lastIndexOf('/') + 1);
}

async function expectPesterPasses(testFile: string) {
  const failures = await runPester(testFile);
  if (failures.length) throw new Error(`Pester tests failed:\n- ${failures.join('\n- ')}`);
}

async function runPester(testFile: string): Promise<string[]> {
  const workDir = mkdtempSync(join(tmpdir(), 'pester-tests-'));
  const failuresFile = join(workDir, 'failures.json');
  try {
    const output: Buffer[] = [];
    const exitCode = await new Promise<number | null>((resolve, reject) => {
      const child = spawn('pwsh', ['-NoProfile', '-NonInteractive', '-Command', pesterScript], {
        env: { ...process.env, PESTER_TEST_FILE: testFile, PESTER_FAILURES_FILE: failuresFile },
        stdio: ['ignore', 'pipe', 'pipe'],
      });
      for (const stream of [child.stdout, child.stderr]) {
        stream.on('data', (chunk: Buffer) => {
          output.push(chunk);
          process.stdout.write(chunk);
        });
      }
      child.on('error', reject);
      child.on('close', resolve);
    });
    let failures: string[];
    try {
      failures = JSON.parse(readFileSync(failuresFile, 'utf8').replace(/^\uFEFF/, '')) ?? [];
    } catch {
      throw new Error(`Pester did not run (exit ${exitCode}):\n${Buffer.concat(output).toString('utf8').trim()}`);
    }
    return failures;
  } finally {
    rmSync(workDir, { recursive: true, force: true });
  }
}