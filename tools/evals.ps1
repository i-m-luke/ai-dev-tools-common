#Requires -Version 7
<#
.SYNOPSIS
Runs the repo's evals and reports which ones failed.

.DESCRIPTION
Two kinds of evals live in the repo's evals folder:
- `evals/*.ps1` — script evals, each run in its own pwsh process; a non-zero exit code is a failure.
- `evals/<skill>/eval.yaml` — skill evals, run by waza (https://github.com/microsoft/waza). Each
  runs from its own folder, because waza also loads skills from the working directory and would
  otherwise pick up the eval stubs of other skills.
Evals of in-progress content live in `evals/in-progress/` with the same layout and run only with
-InProgress.
Exits 0 when all selected evals pass, 1 otherwise.

.PARAMETER Name
Runs only the evals with these names (a script's base name or a skill eval's folder name). Any name
matching no eval is listed and the script exits 1 without running anything.

.PARAMETER InProgress
Runs the in-progress evals instead of the production ones; -Name then picks among them.

.PARAMETER Model
Model the skill evals run on, overriding the `model` in each eval.yaml. Defaults to claude-sonnet-5.5.

.EXAMPLE
./tools/evals.ps1 -Name document-app, shallow-grill

.EXAMPLE
./tools/evals.ps1 -InProgress

.EXAMPLE
./tools/evals.ps1 -Model claude-sonnet-5
#>
param(
    [string[]] $Name,
    [switch] $InProgress,
    [string] $Model = 'claude-sonnet-5.5'
)

$ErrorActionPreference = 'Stop'

$evalsDir = Join-Path $PSScriptRoot '..' 'evals'
if ($InProgress) { $evalsDir = Join-Path $evalsDir 'in-progress' }
$allEvals = @(
    Get-ChildItem -Path $evalsDir -Filter '*.ps1' -File |
        ForEach-Object { [pscustomobject] @{ Name = $_.BaseName; Kind = 'script'; Path = $_.FullName } }
    Get-ChildItem -Path $evalsDir -Filter 'eval.yaml' -File -Recurse -Depth 1 |
        ForEach-Object { [pscustomobject] @{ Name = $_.Directory.Name; Kind = 'waza'; Path = $_.FullName } }
)

$unknown = @($Name ? ($Name | Where-Object { $_ -notin $allEvals.Name }) : @())
if ($unknown.Count) {
    Write-Host "Unknown evals: $($unknown -join ', ')"
    exit 1
}

$evals = @($allEvals | Where-Object { -not $Name -or $_.Name -in $Name } | Sort-Object Name)

if (-not $evals) {
    Write-Host "No evals found in $evalsDir"
    exit 0
}

if ($evals.Kind -contains 'waza') {
    $waza = (Get-Command waza -ErrorAction SilentlyContinue)?.Source
    $defaultWaza = Join-Path $env:LOCALAPPDATA 'Microsoft' 'Waza' 'waza.exe'
    if (-not $waza -and (Test-Path $defaultWaza)) { $waza = $defaultWaza }
    if (-not $waza) { throw 'waza not found; install it (see docs/verification/evals.md).' }
    & (Join-Path $PSScriptRoot 'use-copilot-account.ps1')
}

# Fixtures holding an AGENTS.md test the shared instructions: they get a copy of the real ones
# (copy, not symlink: waza copies fixtures into a temp workspace). The copies are git-ignored.
$repoRoot = Join-Path $PSScriptRoot '..'
$sharedInstructions = @('AGENTS-SHARED.md', 'agents-shared')
function Get-SharedInstructionFixtures([string] $EvalDir) {
    $fixturesDir = Join-Path $EvalDir 'fixtures'
    if (Test-Path $fixturesDir) {
        Get-ChildItem $fixturesDir -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'AGENTS.md') }
    }
}
$usageRows = [System.Collections.Generic.List[object]]::new()
$results = [System.Collections.Generic.List[object]]::new()
$startedAt = Get-Date
$modelPrices = Get-Content (Join-Path $PSScriptRoot 'model-prices.json') -Raw | ConvertFrom-Json

# Estimated GitHub AI credits (1 credit = $0.01) from token counts; $null when the model has no price.
# waza's input_tokens include the cache read and write tokens, so only the rest is billed as input.
function Get-EstimatedCredits([string] $ModelName, $Usage) {
    $price = $modelPrices.$ModelName
    if (-not $price) { return $null }
    $uncachedInput = [math]::Max(0, $Usage.input_tokens - $Usage.cache_read_tokens - $Usage.cache_write_tokens)
    ($uncachedInput * $price.input + $Usage.output_tokens * $price.output +
        $Usage.cache_read_tokens * $price.cachedInput + $Usage.cache_write_tokens * $price.cacheWrite) / 1e6 * 100
}

# waza prints UTF-8 (box-drawing characters, check marks); decode it as such whatever the console code page.
$originalOutputEncoding = [Console]::OutputEncoding
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$failed = foreach ($eval in $evals) {
    Write-Host "=== $($eval.Name)"
    if ($eval.Kind -eq 'script') {
        & pwsh -NoProfile -File $eval.Path | Out-Host
    }
    else {
        $evalDir = Split-Path $eval.Path
        $fixtures = @(Get-SharedInstructionFixtures $evalDir)
        $usageFile = [System.IO.Path]::GetTempFileName()
        Push-Location $evalDir
        try {
            foreach ($fixture in $fixtures) {
                foreach ($item in $sharedInstructions) {
                    Copy-Item (Join-Path $repoRoot $item) $fixture.FullName -Recurse -Force
                }
            }
            & $waza run eval.yaml --model $Model --no-update-check -o $usageFile | Out-Host
        }
        finally {
            Pop-Location
            foreach ($fixture in $fixtures) {
                foreach ($item in $sharedInstructions) {
                    Remove-Item (Join-Path $fixture.FullName $item) -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
            $usage = try { (Get-Content $usageFile -Raw | ConvertFrom-Json).summary.usage } catch { $null }
            Remove-Item $usageFile -ErrorAction SilentlyContinue
            if ($usage) {
                $usageRows.Add([pscustomobject] @{
                        Eval               = $eval.Name
                        Input              = [long] $usage.input_tokens
                        Output             = [long] $usage.output_tokens
                        'Cache read'       = [long] $usage.cache_read_tokens
                        'Cache write'      = [long] $usage.cache_write_tokens
                        'Est. credits'     = Get-EstimatedCredits $Model $usage
                        'Premium requests' = [double] $usage.premium_requests
                    })
            }
        }
    }
    $results.Add([pscustomobject] @{ Eval = $eval.Name; Kind = $eval.Kind; ExitCode = $LASTEXITCODE })
    if ($LASTEXITCODE) {
        Write-Host "--- $($eval.Name): FAIL (exit $LASTEXITCODE)"
        $eval.Name
    }
    else { Write-Host "--- $($eval.Name): PASS" }
}

$failed = @($failed)
[Console]::OutputEncoding = $originalOutputEncoding
$total = $null
if ($usageRows.Count) {
    $columns = 'Input', 'Output', 'Cache read', 'Cache write', 'Est. credits', 'Premium requests'
    $decimalFormats = @{ 'Est. credits' = '0.#'; 'Premium requests' = '0.##' }
    $total = [pscustomobject] @{ Eval = 'Total' }
    foreach ($column in $columns) {
        $total | Add-Member -NotePropertyName $column -NotePropertyValue ($usageRows | Measure-Object $column -Sum).Sum
    }
    $format = @(@{ Expression = 'Eval' }) + @($columns | ForEach-Object {
            @{ Expression = [string] $_; FormatString = $decimalFormats[$_] ?? 'N0'; Alignment = 'Right' }
        })
    Write-Host 'Token usage (waza evals):'
    $table = @($usageRows) + $total | Format-Table -Property $format -AutoSize | Out-String
    Write-Host $table.TrimEnd()
    Write-Host 'Est. credits: GitHub AI credits estimated from tokens and tools/model-prices.json (blank = model has no price). Premium requests: legacy unit, replaced by AI credits on 2026-06-01.'
}
Write-Host "Passed $($evals.Count - $failed.Count)/$($evals.Count) evals"
if ($failed) { Write-Host "Failed: $($failed -join ', ')" }

# Markdown report in .artifacts/, the repo's file exchange with the user (git-ignored).
$reportDir = Join-Path $repoRoot '.artifacts'
New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
$reportPath = Join-Path $reportDir "evals-report-$($startedAt.ToString('yyyyMMdd-HHmmss')).md"
$report = [System.Collections.Generic.List[string]]::new()
$report.Add('# Evals report')
$report.Add('')
$report.Add("- Started: $($startedAt.ToString('yyyy-MM-dd HH:mm:ss'))")
$report.Add("- Duration: $(((Get-Date) - $startedAt).ToString('hh\:mm\:ss'))")
$report.Add("- Scope: $($InProgress ? 'in-progress' : 'production') evals")
$report.Add("- Model (skill evals): ``$Model``")
$report.Add("- Result: $($failed ? 'FAIL' : 'PASS') ($($evals.Count - $failed.Count)/$($evals.Count) passed)")
$report.Add('')
$report.Add('## Evals')
$report.Add('')
$report.Add('| Eval | Kind | Result |')
$report.Add('|---|---|---|')
foreach ($result in $results) {
    $report.Add("| $($result.Eval) | $($result.Kind) | $($result.ExitCode ? "FAIL (exit $($result.ExitCode))" : 'PASS') |")
}
if ($usageRows.Count) {
    $report.Add('')
    $report.Add('## Token usage (waza evals)')
    $report.Add('')
    $report.Add('| Eval | Input | Output | Cache read | Cache write | Est. credits | Premium requests |')
    $report.Add('|---|--:|--:|--:|--:|--:|--:|')
    foreach ($row in @($usageRows) + $total) {
        $credits = $null -eq $row.'Est. credits' ? '' : $row.'Est. credits'.ToString('0.#')
        $report.Add("| $($row.Eval) | $($row.Input.ToString('N0')) | $($row.Output.ToString('N0')) | $($row.'Cache read'.ToString('N0')) | $($row.'Cache write'.ToString('N0')) | $credits | $($row.'Premium requests'.ToString('0.##')) |")
    }
    $report.Add('')
    $report.Add('Est. credits: GitHub AI credits estimated from tokens and `tools/model-prices.json` (blank = model has no price).')
}
$report | Set-Content -Path $reportPath -Encoding utf8
Write-Host "Report: $((Resolve-Path $reportPath).Path)"
exit ($failed ? 1 : 0)
