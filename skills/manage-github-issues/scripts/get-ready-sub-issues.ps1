<#
.SYNOPSIS
Lists the sub-issues of an issue that are ready to be worked on.

.DESCRIPTION
A sub-issue is ready when it is open, has no assignee and no open blocker. They are listed in the
parent's sub-issue order, so the first one is the next to take.

.PARAMETER Repository
The GitHub repository as `<owner>/<name>`.

.PARAMETER Parent
The number of the parent issue.

.OUTPUTS
::result::[{"number":<number>,"title":"…","url":"…"}]

.NOTES
Exit codes:
- 0: the ready sub-issues are listed; the list may be empty.
- 2: GitHub rejected the request, e.g. the parent issue does not exist.
- 3: sub-issues are not available in the repository.

Stderr: the reason of the failure, followed by the output of GitHub CLI.
#>
param(
    [Parameter(Mandatory)] [ValidatePattern('^[\w.-]+/[\w.-]+$')] [string] $Repository,
    [Parameter(Mandatory)] [ValidateRange(1, [int]::MaxValue)] [int] $Parent
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
Import-Module (Join-Path $PSScriptRoot 'github-client.psm1')

# Reading the parent first leaves an HTTP 404 of the sub-issues endpoint meaning the feature is missing.
Invoke-GhApi -Path "repos/$Repository/issues/$Parent" -Action "read the parent issue #$Parent" | Out-Null
$children = @(Get-GhApiPages -Path "repos/$Repository/issues/$Parent/sub_issues" -Action "list the sub-issues of #$Parent" `
        -NotFoundCode 3 -NotFoundMessage "Sub-issues are not available in $Repository.")

$ready = @(foreach ($child in $children) {
        if ($child.state -ne 'open' -or @(Get-Names $child.assignees 'login').Count) { continue }
        $dependencies = $child.issue_dependencies_summary
        if (-not $dependencies) {
            $dependencies = (Invoke-GhApi -Path "repos/$Repository/issues/$($child.number)" -Action "read #$($child.number)").issue_dependencies_summary
        }
        # blocked_by counts the open blockers only.
        if ($dependencies -and $dependencies.blocked_by) { continue }
        [ordered] @{ number = $child.number; title = $child.title; url = $child.html_url }
    })

Write-Result $ready
