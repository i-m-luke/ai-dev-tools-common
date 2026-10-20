import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import type { EvalOutcome, Usage } from "./waza.ts";

interface Price {
  input: number;
  cachedInput: number;
  cacheWrite: number;
  output: number;
}

interface UsageRow {
  eval: string;
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
  credits: number | undefined;
  premiumRequests: number;
}

const creditsNote =
  "Est. credits: GitHub AI credits estimated from tokens and `tests/evals-executor/model-prices.json` (blank = model has no price).";

// Collects the outcome of each eval of a run and writes the run's report.md and token usage table.
export class EvalsReport {
  readonly runDir: string;
  private readonly startedAt = new Date();
  private readonly results: { eval: string; exitCode: number | null }[] = [];
  private readonly usageRows: UsageRow[] = [];
  private readonly prices: Record<string, Price | undefined>;
  private readonly scope: string;
  private readonly model: string;

  constructor(repoRoot: string, scope: string, model: string) {
    this.scope = scope;
    this.model = model;
    // .artifacts/ is the repo's file exchange with the user (git-ignored).
    this.runDir = join(repoRoot, ".artifacts", "evals-reports", timestamp(this.startedAt));
    this.prices = JSON.parse(readFileSync(join(import.meta.dirname, "model-prices.json"), "utf8"));
  }

  get isEmpty() {
    return this.results.length === 0;
  }

  add(evalName: string, outcome: EvalOutcome) {
    this.results.push({ eval: evalName, exitCode: outcome.exitCode });
    if (!outcome.usage) return;
    const usage = outcome.usage;
    this.usageRows.push({
      eval: evalName,
      input: usage.input_tokens,
      output: usage.output_tokens,
      cacheRead: usage.cache_read_tokens,
      cacheWrite: usage.cache_write_tokens,
      credits: this.estimateCredits(usage),
      premiumRequests: usage.premium_requests,
    });
  }

  // Prints the token usage table and writes report.md; returns the report's path.
  write(): string {
    const rows = this.tableRows();
    if (rows.length) {
      console.log(`Token usage (waza evals):\n${formatTable(rows)}`);
    }

    const failed = this.results.filter((result) => result.exitCode !== 0);
    const passed = `${this.results.length - failed.length}/${this.results.length} passed`;
    const lines = [
      "# Evals report",
      "",
      `- Started: ${this.startedAt.toLocaleString("sv-SE")}`,
      `- Duration: ${duration(Date.now() - this.startedAt.getTime())}`,
      `- Scope: ${this.scope} evals`,
      `- Model: \`${this.model}\``,
      `- Result: ${failed.length ? "FAIL" : "PASS"} (${passed})`,
      "",
      "## Evals",
      "",
      "| Eval | Result |",
      "|---|---|",
      ...this.results.map(
        (result) => `| ${result.eval} | ${result.exitCode === 0 ? "PASS" : `FAIL (exit ${result.exitCode})`} |`,
      ),
    ];
    if (rows.length) {
      lines.push("", "## Token usage", "", `| ${rows[0].join(" | ")} |`, "|---|--:|--:|--:|--:|--:|--:|");
      lines.push(...rows.slice(1).map((row) => `| ${row.join(" | ")} |`), "", creditsNote);
    }

    mkdirSync(this.runDir, { recursive: true });
    const reportPath = join(this.runDir, "report.md");
    writeFileSync(reportPath, `${lines.join("\n")}\n`);
    return reportPath;
  }

  // Estimated GitHub AI credits (1 credit = $0.01); undefined when the model has no price.
  // waza's input_tokens include the cache read and write tokens, so only the rest is billed as input.
  private estimateCredits(usage: Usage): number | undefined {
    const price = this.prices[this.model];
    if (!price) return undefined;
    const uncachedInput = Math.max(0, usage.input_tokens - usage.cache_read_tokens - usage.cache_write_tokens);
    const usd =
      uncachedInput * price.input +
      usage.output_tokens * price.output +
      usage.cache_read_tokens * price.cachedInput +
      usage.cache_write_tokens * price.cacheWrite;
    return (usd / 1e6) * 100;
  }

  private tableRows(): string[][] {
    if (!this.usageRows.length) return [];
    const sum = (pick: (row: UsageRow) => number | undefined) =>
      this.usageRows.reduce((total, row) => total + (pick(row) ?? 0), 0);
    const total: UsageRow = {
      eval: "Total",
      input: sum((row) => row.input),
      output: sum((row) => row.output),
      cacheRead: sum((row) => row.cacheRead),
      cacheWrite: sum((row) => row.cacheWrite),
      credits: this.usageRows.some((row) => row.credits !== undefined) ? sum((row) => row.credits) : undefined,
      premiumRequests: sum((row) => row.premiumRequests),
    };
    const integer = (value: number) => value.toLocaleString("en-US");
    const decimal = (value: number | undefined, digits: number) =>
      value === undefined ? "" : value.toLocaleString("en-US", { maximumFractionDigits: digits });
    return [
      ["Eval", "Input", "Output", "Cache read", "Cache write", "Est. credits"],
      ...[...this.usageRows, total].map((row) => [
        row.eval,
        integer(row.input),
        integer(row.output),
        integer(row.cacheRead),
        integer(row.cacheWrite),
        decimal(row.credits, 1),
      ]),
    ];
  }
}

function formatTable(rows: string[][]): string {
  const widths = rows[0].map((_, column) => Math.max(...rows.map((row) => row[column].length)));
  return rows
    .map((row) =>
      row.map((cell, column) => (column ? cell.padStart(widths[column]) : cell.padEnd(widths[column]))).join("  "),
    )
    .join("\n");
}

function timestamp(date: Date): string {
  const pad = (value: number) => String(value).padStart(2, "0");
  return (
    `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}-` +
    `${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}`
  );
}

function duration(ms: number): string {
  const seconds = Math.round(ms / 1000);
  const pad = (value: number) => String(value).padStart(2, "0");
  return `${pad(Math.floor(seconds / 3600))}:${pad(Math.floor(seconds / 60) % 60)}:${pad(seconds % 60)}`;
}
