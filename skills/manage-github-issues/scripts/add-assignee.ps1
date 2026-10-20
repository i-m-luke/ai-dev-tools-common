<#
.SYNOPSIS
Assigns a user to an issue or a pull request.

.PARAMETER Repository
The GitHub repository as `<owner>/<name>`.

.PARAMETER Number
The issue or pull request number.

.PARAMETER Assignee
The login to assign; `@me` (default) for the account GitHub CLI is logged in as.

.OUTPUTS
::result::{"assignees":["<every login assigned afterwards>"]}

.NOTES
Exit codes:
- 0: the user is assigned.
- 2: GitHub rejected the request, e.g. no issue or pull request has the number.
- 3: the user cannot be assigned, e.g. lacks access to the repository; GitHub skips such a user
  without an error.

Stderr: the reason of the failure, followed by the output of GitHub CLI.
#>
param(
    [Parameter(Mandatory)] [ValidatePattern('^[\w.-]+/[\w.-]+$')] [string] $Repository,
    [Parameter(Mandatory)] [ValidateRange(1, [int]::MaxValue)] [int] $Number,
    [string] $Assignee = '@me'
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
Import-Module (Join-Path $PSScriptRoot 'github-client.psm1')

$login = if ($Assignee -eq '@me') {
    (Invoke-GhApi -Path 'user' -Action 'read the logged-in account').login
} else {
    $Assignee
}

$item = Invoke-GhApi -Path "repos/$Repository/issues/$Number/assignees" -Method POST `
    -Body @{ assignees = @($login) } -Action "assign $login to #$Number"
$assignees = @(Get-Names $item.assignees 'login')

if ($assignees -notcontains $login) {
    Stop-WithError 3 "GitHub did not assign $login to #$Number of $Repository; the user may lack access to the repository."
}

Write-Result ([ordered] @{ assignees = $assignees })
