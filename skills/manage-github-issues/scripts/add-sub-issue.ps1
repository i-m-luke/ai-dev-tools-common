<#
.SYNOPSIS
Makes an issue a sub-issue of another.

.DESCRIPTION
Links the child under the parent with GitHub's native sub-issues; the child appears last in the
parent's sub-issue list. An issue has at most one parent.

.PARAMETER Repository
The GitHub repository as `<owner>/<name>`.

.PARAMETER Parent
The number of the parent issue.

.PARAMETER Child
The number of the issue to put under the parent.

.OUTPUTS
None.

.NOTES
Exit codes:
- 0: the child is a sub-issue of the parent.
- 20: GitHub rejected the request, e.g. an issue does not exist or the child already has a parent.
- 21: sub-issues are not available in the repository.

Stderr: the reason of the failure, followed by the output of GitHub CLI.
#>
param(
    [Parameter(Mandatory)] [ValidatePattern('^[\w.-]+/[\w.-]+$')] [string] $Repository,
    [Parameter(Mandatory)] [ValidateRange(1, [int]::MaxValue)] [int] $Parent,
    [Parameter(Mandatory)] [ValidateRange(1, [int]::MaxValue)] [int] $Child
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
Import-Module (Join-Path $PSScriptRoot 'github-client.psm1')

# Reading both issues first leaves an HTTP 404 of the sub-issues endpoint meaning the feature is missing.
Invoke-GhApi -Path "repos/$Repository/issues/$Parent" -Action "read the parent issue #$Parent" | Out-Null
$childId = (Invoke-GhApi -Path "repos/$Repository/issues/$Child" -Action "read the child issue #$Child").id

Invoke-GhApi -Path "repos/$Repository/issues/$Parent/sub_issues" -Method POST -Body @{ sub_issue_id = $childId } `
    -Action "add #$Child as a sub-issue of #$Parent" `
    -NotFoundCode 21 -NotFoundMessage "Sub-issues are not available in $Repository." | Out-Null

Write-Host "#$Child is a sub-issue of #$Parent."
