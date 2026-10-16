import { spawn } from 'node:child_process';
import { mkdtempSync, readdirSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { expect, it } from 'vitest';

// Runs Pester files (`*.Tests.ps1`) under tests/script-tests as Vitest tests.
const scriptTestsDir = join(import.meta.dirname, '..', 'script-tests');

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

// The files passed to pesterTest; test files list each by name so the VS Code Test Explorer, which
// finds tests by reading the source, shows them before a run.
const declared: string[] = [];

// Runs the Pester file tests/script-tests/<file> as one test, in its own pwsh process.
export function pesterTest(file: string) {
  declared.push(file);
  it(file, async () => {
    const failures = await runPester(join(scriptTestsDir, file));
    if (failures.length) throw new Error(`Pester tests failed:\n- ${failures.join('\n- ')}`);
  });
}

// Fails when the pesterTest calls and the Pester files differ, so no file is left out.
export function expectAllPesterFilesDeclared() {
  const found = readdirSync(scriptTestsDir, { recursive: true, encoding: 'utf8' })
    .filter((file) => file.endsWith('.Tests.ps1'))
    .map((file) => file.replaceAll('\\', '/'));
  expect([...declared].sort(), `pesterTest calls must match the files in ${scriptTestsDir}`).toEqual(found.sort());
}

async function runPester(testFile: string): Promise<string[]> {
  const workDir = mkdtempSync(join(tmpdir(), 'script-tests-'));
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
