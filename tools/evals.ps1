#Requires -Version 7
<#
.SYNOPSIS
Runs every eval script in the repo's evals folder and reports which ones failed.

.DESCRIPTION
Each eval runs in its own pwsh process; a non-zero exit code counts as a failure.
Exits 0 when all evals pass, 1 otherwise.
#>

$ErrorActionPreference = 'Stop'

$evalsDir = Join-Path $PSScriptRoot '..' 'evals'
$evals = @(Get-ChildItem -Path $evalsDir -Filter '*.ps1' -File | Sort-Object Name)
if (-not $evals) {
    Write-Host "No evals found in $evalsDir"
    exit 0
}

$failed = foreach ($eval in $evals) {
    Write-Host "=== $($eval.Name)"
    & pwsh -NoProfile -File $eval.FullName | Out-Host
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