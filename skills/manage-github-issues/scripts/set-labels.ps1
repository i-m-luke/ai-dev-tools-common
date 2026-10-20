<#
.SYNOPSIS
Adds labels to and removes labels from an issue or a pull request.

.DESCRIPTION
Adds the labels first, then removes the others; GitHub creates an added label that does not exist
yet, and removing a label the item does not carry changes nothing.

.PARAMETER Repository
The GitHub repository as `<owner>/<name>`.

.PARAMETER Number
The issue or pull request number.

.PARAMETER Add
Optional comma-separated labels to add, e.g. `ready-for-agent`.

.PARAMETER Remove
Optional comma-separated labels to remove, e.g. `needs-triage,needs-info`.

.OUTPUTS
::result::{"labels":["<every label the item carries afterwards>"]}

.NOTES
Exit codes:
- 0: the labels are changed.
- 2: GitHub rejected the request, e.g. no issue or pull request has the number.

Stderr: the reason of the failure, followed by the output of GitHub CLI.
#>
param(
    [Parameter(Mandatory)] [ValidatePattern('^[\w.-]+/[\w.-]+$')] [string] $Repository,
    [Parameter(Mandatory)] [ValidateRange(1, [int]::MaxValue)] [int] $Number,
    [string] $Add,
    [string] $Remove
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
Import-Module (Join-Path $PSScriptRoot 'github-client.psm1')

$path = "repos/$Repository/issues/$Number/labels"
$toAdd = @(Split-List $Add)
if ($toAdd.Count) {
    Invoke-GhApi -Path $path -Method POST -Body @{ labels = $toAdd } -Action "add labels to #$Number" | Out-Null
}
foreach ($name in (Split-List $Remove)) {
    Invoke-GhApi -Path "$path/$([Uri]::EscapeDataString($name))" -Method DELETE -IgnoreNotFound `
        -Action "remove the label '$name' from #$Number" | Out-Null
}

$labels = @(Get-GhApiPages -Path $path -Action "read the labels of #$Number" | ForEach-Object { $_.name })

Write-Result ([ordered] @{ labels = $labels })
