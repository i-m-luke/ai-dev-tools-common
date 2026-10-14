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

.EXAMPLE
./tools/evals.ps1 -Name document-app, shallow-grill

.EXAMPLE
./tools/evals.ps1 -InProgress
#>
param(
    [string[]] $Name,
    [switch] $InProgress
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
            & $waza run eval.yaml --no-update-check -o $usageFile | Out-Host
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
                        'Premium requests' = [double] $usage.premium_requests
                    })
            }
        }
    }
    if ($LASTEXITCODE) {
        Write-Host "--- $($eval.Name): FAIL (exit $LASTEXITCODE)"
        $eval.Name
    }
    else { Write-Host "--- $($eval.Name): PASS" }
}

$failed = @($failed)
if ($usageRows.Count) {
    $columns = 'Input', 'Output', 'Cache read', 'Cache write', 'Premium requests'
    $total = [pscustomobject] @{ Eval = 'Total' }
    foreach ($column in $columns) {
        $total | Add-Member -NotePropertyName $column -NotePropertyValue ($usageRows | Measure-Object $column -Sum).Sum
    }
    $format = @(@{ Expression = 'Eval' }) + @($columns | ForEach-Object {
            @{ Expression = [string] $_; FormatString = $_ -eq 'Premium requests' ? '0.##' : 'N0'; Alignment = 'Right' }
        })
    Write-Host 'Token usage (waza evals):'
    $table = @($usageRows) + $total | Format-Table -Property $format -AutoSize | Out-String
    Write-Host $table.TrimEnd()
}
Write-Host "Passed $($evals.Count - $failed.Count)/$($evals.Count) evals"
if ($failed) { Write-Host "Failed: $($failed -join ', ')" }
exit ($failed ? 1 : 0)
