<#
.SYNOPSIS
Marks an issue as blocked by another.

.DESCRIPTION
Adds a native GitHub issue dependency: the issue stays blocked until the blocker is closed.

.PARAMETER Repository
The GitHub repository as `<owner>/<name>`.

.PARAMETER Issue
The number of the blocked issue.

.PARAMETER BlockedBy
The number of the blocking issue.

.OUTPUTS
None.

.NOTES
Exit codes:
- 0: the issue is blocked by the blocker.
- 2: GitHub rejected the request, e.g. an issue does not exist or the dependency already exists.
- 3: issue dependencies are not available in the repository.

Stderr: the reason of the failure, followed by the output of GitHub CLI.
#>
param(
    [Parameter(Mandatory)] [ValidatePattern('^[\w.-]+/[\w.-]+$')] [string] $Repository,
    [Parameter(Mandatory)] [ValidateRange(1, [int]::MaxValue)] [int] $Issue,
    [Parameter(Mandatory)] [ValidateRange(1, [int]::MaxValue)] [int] $BlockedBy
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
Import-Module (Join-Path $PSScriptRoot 'github-client.psm1')

# Reading both issues first leaves an HTTP 404 of the dependencies endpoint meaning the feature is missing.
Invoke-GhApi -Path "repos/$Repository/issues/$Issue" -Action "read the blocked issue #$Issue" | Out-Null
# The endpoint takes the blocker's database id, not its number.
$blockerId = (Invoke-GhApi -Path "repos/$Repository/issues/$BlockedBy" -Action "read the blocking issue #$BlockedBy").id

Invoke-GhApi -Path "repos/$Repository/issues/$Issue/dependencies/blocked_by" -Method POST -Body @{ issue_id = $blockerId } `
    -Action "mark #$Issue as blocked by #$BlockedBy" `
    -NotFoundCode 3 -NotFoundMessage "Issue dependencies are not available in $Repository." | Out-Null

Write-Host "#$Issue is blocked by #$BlockedBy."
