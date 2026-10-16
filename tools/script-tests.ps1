#Requires -Version 7
<#
.SYNOPSIS
Runs the repo's script tests and reports which ones failed.

.DESCRIPTION
Runs every Pester test (`*.Tests.ps1`) in the repo's script-tests folder: the tests of the scripts the skills ship.
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

function Invoke-Tests([string[]] $Path) {
    $config = New-PesterConfiguration
    $config.Run.Path = $Path
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'
    if ([Console]::IsOutputRedirected) {
        $config.Output.RenderMode = 'Plaintext'
    }
    Invoke-Pester -Configuration $config
}

function Get-Reason($Item) {
    $message = $Item.ErrorRecord | Select-Object -First 1 | ForEach-Object { $_.Exception.Message }
    $message ? ": $(($message -split '\r?\n')[0])" : ''
}

function Get-Failures($Result) {
    @(
        $Result.Failed | ForEach-Object { "$($_.ExpandedPath)$(Get-Reason $_)" }
        $Result.FailedBlocks | ForEach-Object { "$($_.ExpandedPath)$(Get-Reason $_)" }
        $Result.FailedContainers | ForEach-Object { "$($_.Item)$(Get-Reason $_)" }
    ) | Where-Object { $_ }
}

$result = Invoke-Tests (Join-Path $PSScriptRoot '..' 'script-tests')
if ($result.Result -eq 'Passed') {
    exit 0
}
Exit-WithFailure (Get-Failures $result)
