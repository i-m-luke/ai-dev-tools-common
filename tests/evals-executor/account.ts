import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

interface EvalsConfig {
  githubUser?: string;
}

// Settings from evals.config.json in the repo root; the file must exist but may be empty.
export function readConfig(repoRoot: string): EvalsConfig {
  const path = join(repoRoot, 'evals.config.json');
  if (!existsSync(path)) throw new Error(`Missing ${path}; create it (it may be empty, see docs/verification/evals.md).`);
  const json = readFileSync(path, 'utf8').replace(/^\uFEFF/, '');
  return json.trim() ? (JSON.parse(json) as EvalsConfig) : {};
}

// Environment that makes Copilot CLI (also the one bundled in waza) use the configured account:
// COPILOT_GITHUB_TOKEN beats every other credential Copilot CLI knows, including GH_TOKEN.
export function copilotAccountEnv(config: EvalsConfig): Record<string, string> {
  if (!config.githubUser) return {};
  try {
    const token = execFileSync('gh', ['auth', 'token', '--hostname', 'github.com', '--user', config.githubUser], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    }).trim();
    return { COPILOT_GITHUB_TOKEN: token };
  } catch (error) {
    throw new Error(`No GitHub CLI token for '${config.githubUser}' (run: gh auth login): ${(error as Error).message}`);
  }
}
