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
Exits 0 when all selected evals pass, 1 otherwise.

.PARAMETER Name
Runs only the evals with these names (a script's base name or a skill eval's folder name).

.EXAMPLE
./tools/evals.ps1 -Name document-app, shallow-grill
#>
param(
    [string[]] $Name
)

$ErrorActionPreference = 'Stop'

$evalsDir = Join-Path $PSScriptRoot '..' 'evals'
$evals = @(
    @(
        Get-ChildItem -Path $evalsDir -Filter '*.ps1' -File |
            ForEach-Object { [pscustomobject] @{ Name = $_.BaseName; Kind = 'script'; Path = $_.FullName } }
        Get-ChildItem -Path $evalsDir -Filter 'eval.yaml' -File -Recurse -Depth 1 |
            ForEach-Object { [pscustomobject] @{ Name = $_.Directory.Name; Kind = 'waza'; Path = $_.FullName } }
    ) | Where-Object { -not $Name -or $_.Name -in $Name } | Sort-Object Name
)

if (-not $evals) {
    Write-Host "No evals found in $evalsDir"
    exit 0
}

if ($evals.Kind -contains 'waza') {
    $waza = (Get-Command waza -ErrorAction SilentlyContinue)?.Source
    $defaultWaza = Join-Path $env:LOCALAPPDATA 'Microsoft' 'Waza' 'waza.exe'
    if (-not $waza -and (Test-Path $defaultWaza)) { $waza = $defaultWaza }
    if (-not $waza) { throw 'waza not found; install it (see README).' }
    & (Join-Path $evalsDir 'utils' 'use-copilot-account.ps1')
}

$failed = foreach ($eval in $evals) {
    Write-Host "=== $($eval.Name)"
    if ($eval.Kind -eq 'script') {
        & pwsh -NoProfile -File $eval.Path | Out-Host
    }
    else {
        Push-Location (Split-Path $eval.Path)
        try { & $waza run eval.yaml --no-update-check | Out-Host }
        finally { Pop-Location }
    }
    if ($LASTEXITCODE) {
        Write-Host "--- $($eval.Name): FAIL (exit $LASTEXITCODE)"
        $eval.Name
    }
    else { Write-Host "--- $($eval.Name): PASS" }
}

$failed = @($failed)
Write-Host "Passed $($evals.Count - $failed.Count)/$($evals.Count) evals"
if ($failed) { Write-Host "Failed: $($failed -join ', ')" }
exit ($failed ? 1 : 0)
