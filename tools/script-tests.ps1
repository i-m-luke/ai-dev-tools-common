#Requires -Version 7
<#
.SYNOPSIS
Runs the repo's script tests and reports which ones failed.

.DESCRIPTION
Runs every Pester test (`*.Tests.ps1`) in the repo's script-tests folder, including the per-skill subfolders.
Exits 0 when all tests pass, 1 otherwise; on failure the output ends with a "Script tests failed:" line
followed by one "- <failure>" line per failure.

.EXAMPLE
./tools/script-tests.ps1
#>

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

function Exit-WithFailure([string[]] $Failures) {
    Write-Host 'Script tests failed:'
    $Failures | ForEach-Object { Write-Host "- $_" }
    exit 1
}

if (-not (Get-Module -ListAvailable Pester | Where-Object Version -GE '5.0')) {
    Exit-WithFailure 'Pester 5+ not found; install it (see docs/verification/script-tests.md).'
}
Import-Module Pester -MinimumVersion 5.0

if (-not (Get-Module -ListAvailable powershell-yaml)) {
    Exit-WithFailure 'powershell-yaml not found; install it (see docs/verification/script-tests.md).'
}

$config = New-PesterConfiguration
$config.Run.Path = Join-Path $PSScriptRoot '..' 'script-tests'
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'
if ([Console]::IsOutputRedirected) {
    $config.Output.RenderMode = 'Plaintext'
}

$result = Invoke-Pester -Configuration $config
if ($result.Result -eq 'Passed') {
    exit 0
}

function Get-Reason($Item) {
    $message = $Item.ErrorRecord | Select-Object -First 1 | ForEach-Object { $_.Exception.Message }
    $message ? ": $(($message -split '\r?\n')[0])" : ''
}

$failures = @(
    $result.Failed | ForEach-Object { "$($_.ExpandedPath)$(Get-Reason $_)" }
    $result.FailedBlocks | ForEach-Object { "$($_.ExpandedPath)$(Get-Reason $_)" }
    $result.FailedContainers | ForEach-Object { "$($_.Item)$(Get-Reason $_)" }
) | Where-Object { $_ }
Exit-WithFailure $failures
