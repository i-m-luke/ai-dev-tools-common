import { spawn } from 'node:child_process';
import { cpSync, createWriteStream, existsSync, mkdirSync, readdirSync, readFileSync, rmSync } from 'node:fs';
import { delimiter, join } from 'node:path';

export interface Usage {
  input_tokens: number;
  output_tokens: number;
  cache_read_tokens: number;
  cache_write_tokens: number;
  premium_requests: number;
}

export interface EvalOutcome {
  exitCode: number | null;
  usage?: Usage;
}

const sharedInstructions = ['AGENTS-SHARED.md', 'agents-shared'];

export function findWaza(): string {
  const names = process.platform === 'win32' ? ['waza.exe', 'waza'] : ['waza'];
  const dirs = (process.env.PATH ?? '').split(delimiter).filter(Boolean);
  if (process.env.LOCALAPPDATA) dirs.push(join(process.env.LOCALAPPDATA, 'Microsoft', 'Waza'));
  for (const dir of dirs) {
    for (const name of names) {
      if (existsSync(join(dir, name))) return join(dir, name);
    }
  }
  throw new Error('waza not found; install it (see docs/verification/evals.md).');
}

// Runs the eval from its own folder, since waza also loads skills from the working directory and
// would otherwise pick up the eval stubs of other skills. Its output lands in outDir.
export async function runEval(options: {
  waza: string;
  evalDir: string;
  outDir: string;
  model: string;
  repoRoot: string;
  env: Record<string, string>;
}): Promise<EvalOutcome> {
  const { waza, evalDir, outDir, model, repoRoot, env } = options;
  mkdirSync(outDir, { recursive: true });
  const resultsFile = join(outDir, 'results.json');
  const fixtures = sharedInstructionFixtures(evalDir);
  try {
    for (const fixture of fixtures) {
      for (const item of sharedInstructions) cpSync(join(repoRoot, item), join(fixture, item), { recursive: true });
    }
    const args = ['run', 'eval.yaml', '--model', model, '--no-update-check', '-o', resultsFile,
      '--transcript-dir', join(outDir, 'transcripts')];
    const exitCode = await runTeed(waza, args, evalDir, { ...process.env, ...env }, join(outDir, 'console.txt'));
    return { exitCode, usage: readUsage(resultsFile) };
  } finally {
    for (const fixture of fixtures) {
      for (const item of sharedInstructions) rmSync(join(fixture, item), { recursive: true, force: true });
    }
  }
}

// Fixtures holding an AGENTS.md test the shared instructions: they get a copy of the real ones
// (copy, not symlink: waza copies fixtures into a temp workspace). The copies are git-ignored.
function sharedInstructionFixtures(evalDir: string): string[] {
  const fixturesDir = join(evalDir, 'fixtures');
  if (!existsSync(fixturesDir)) return [];
  return readdirSync(fixturesDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && existsSync(join(fixturesDir, entry.name, 'AGENTS.md')))
    .map((entry) => join(fixturesDir, entry.name));
}

function readUsage(resultsFile: string): Usage | undefined {
  try {
    return JSON.parse(readFileSync(resultsFile, 'utf8')).summary?.usage;
  } catch {
    return undefined;
  }
}

function runTeed(command: string, args: string[], cwd: string, env: NodeJS.ProcessEnv, logFile: string) {
  const log = createWriteStream(logFile);
  return new Promise<number | null>((resolve, reject) => {
    const child = spawn(command, args, { cwd, env, stdio: ['ignore', 'pipe', 'pipe'] });
    for (const stream of [child.stdout, child.stderr]) {
      stream.on('data', (chunk: Buffer) => {
        log.write(chunk);
        process.stdout.write(chunk);
      });
    }
    child.on('error', reject);
    child.on('close', (code) => log.end(() => resolve(code)));
  });
}
