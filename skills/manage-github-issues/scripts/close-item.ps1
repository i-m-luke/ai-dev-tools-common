<#
.SYNOPSIS
Closes an issue or a pull request, optionally with a closing comment.

.DESCRIPTION
Posts the comment first, then closes the item. An issue closes with a reason; a pull request closes
without merging, and the reason does not apply to it.

.PARAMETER Repository
The GitHub repository as `<owner>/<name>`.

.PARAMETER Number
The issue or pull request number.

.PARAMETER CommentPath
Optional UTF-8 file holding the closing comment in Markdown.

.PARAMETER Reason
Why an issue closes: `completed` (default) or `not_planned`.

.OUTPUTS
::result::{"number":<number>,"kind":"issue|pr"}

.NOTES
Exit codes:
- 0: the item is closed.
- 20: GitHub rejected the request, e.g. no issue or pull request has the number.

Stderr: the reason of the failure, followed by the output of GitHub CLI.
#>
param(
    [Parameter(Mandatory)] [ValidatePattern('^[\w.-]+/[\w.-]+$')] [string] $Repository,
    [Parameter(Mandatory)] [ValidateRange(1, [int]::MaxValue)] [int] $Number,
    [string] $CommentPath,
    [ValidateSet('completed', 'not_planned')] [string] $Reason = 'completed'
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
Import-Module (Join-Path $PSScriptRoot 'github-client.psm1')

$comment = if ($CommentPath) { Read-TextFile $CommentPath }
$item = Invoke-GhApi -Path "repos/$Repository/issues/$Number" -Action "read #$Number of $Repository"

if ($comment) {
    Invoke-GhApi -Path "repos/$Repository/issues/$Number/comments" -Method POST -Body @{ body = $comment } `
        -Action "comment on #$Number" | Out-Null
}

if ($item.pull_request) {
    Invoke-GhApi -Path "repos/$Repository/pulls/$Number" -Method PATCH -Body @{ state = 'closed' } `
        -Action "close pull request #$Number" | Out-Null
} else {
    Invoke-GhApi -Path "repos/$Repository/issues/$Number" -Method PATCH -Body @{ state = 'closed'; state_reason = $Reason } `
        -Action "close issue #$Number" | Out-Null
}

Write-Result ([ordered] @{ number = $Number; kind = if ($item.pull_request) { 'pr' } else { 'issue' } })
