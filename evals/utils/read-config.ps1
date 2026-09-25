#Requires -Version 7
<#
.SYNOPSIS
Returns the evals configuration from `evals.config.json` in the repo root.

.DESCRIPTION
Returns the parsed file as an object (with no properties when the file is empty); settings the file
omits read as $null. Throws when the file is missing or is not valid JSON.

.EXAMPLE
$config = & (Join-Path $PSScriptRoot 'utils' 'read-config.ps1')
#>

$ErrorActionPreference = 'Stop'

$configPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..' '..' 'evals.config.json'))
if (-not (Test-Path -Path $configPath -PathType Leaf)) {
    throw "Missing $configPath; create it (it may be empty, see README)."
}

$json = Get-Content -Raw -Path $configPath
if ([string]::IsNullOrWhiteSpace($json)) { return [pscustomobject] @{} }
$json | ConvertFrom-Json
