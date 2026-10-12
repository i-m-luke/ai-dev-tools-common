#Requires -Version 7
<#
.SYNOPSIS
Runs the repo's script tests and reports which ones failed.

.DESCRIPTION
Runs every Pester test (`*.Tests.ps1`) in the repo's script-tests folder.
Exits 0 when all tests pass, 1 otherwise.

.EXAMPLE
./tools/script-tests.ps1
#>

$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable Pester | Where-Object Version -GE '5.0')) {
    throw 'Pester 5+ not found; install it (see README).'
}
Import-Module Pester -MinimumVersion 5.0

$config = New-PesterConfiguration
$config.Run.Path = Join-Path $PSScriptRoot '..' 'script-tests'
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'

$result = Invoke-Pester -Configuration $config
exit ($result.Result -eq 'Passed' ? 0 : 1)
