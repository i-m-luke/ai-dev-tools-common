#Requires -Version 7
<#
.SYNOPSIS
Runs the repo checks and reports which ones failed.

.DESCRIPTION
Runs every Pester test (`*.Tests.ps1`) in tools/repo-checks: the repo's conventions.
The checks' own tests (`*.Fixtures.Tests.ps1`) run first; when one fails, the rest is skipped, since broken
checks cannot validate the skills.
Exits 0 when all tests pass, 1 otherwise; on failure the output ends with a "Repo checks failed:" line
followed by one "- <failure>" line per failure.

.EXAMPLE
./tools/repo-checks.ps1
#>

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

function Exit-WithFailure([string[]] $Failures) {
    Write-Host 'Repo checks failed:'
    $Failures | ForEach-Object { Write-Host "- $_" }
    exit 1
}

if (-not (Get-Module -ListAvailable Pester | Where-Object Version -GE '5.0')) {
    Exit-WithFailure 'Pester 5+ not found; install it (see docs/verification/repository-checks.md).'
}
Import-Module Pester -MinimumVersion 5.0

if (-not (Get-Module -ListAvailable powershell-yaml)) {
    Exit-WithFailure 'powershell-yaml not found; install it (see docs/verification/repository-checks.md).'
}

function Invoke-Tests([string[]] $Path, [string[]] $ExcludePath = @()) {
    $config = New-PesterConfiguration
    $config.Run.Path = $Path
    $config.Run.ExcludePath = $ExcludePath
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

$checksRoot = Join-Path $PSScriptRoot 'repo-checks'
$checkTests = @(Get-ChildItem -LiteralPath $checksRoot -Recurse -File -Filter '*.Fixtures.Tests.ps1' | ForEach-Object FullName)

if ($checkTests) {
    $result = Invoke-Tests $checkTests
    if ($result.Result -ne 'Passed') {
        Exit-WithFailure @(
            'The checks are broken, so the remaining tests were skipped; fix these first:'
            Get-Failures $result
        )
    }
}

$result = Invoke-Tests $checksRoot -ExcludePath $checkTests
if ($result.Result -eq 'Passed') {
    exit 0
}
Exit-WithFailure (Get-Failures $result)
