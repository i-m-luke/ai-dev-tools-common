<#
.SYNOPSIS
Comments on an issue or a pull request.

.PARAMETER Repository
The GitHub repository as `<owner>/<name>`.

.PARAMETER Number
The issue or pull request number.

.PARAMETER BodyPath
A UTF-8 file holding the comment in Markdown.

.OUTPUTS
::result::{"url":"<comment URL>"}

.NOTES
Exit codes:
- 0: the comment is posted.
- 2: GitHub rejected the request, e.g. no issue or pull request has the number.

Stderr: the reason of the failure, followed by the output of GitHub CLI.
#>
param(
    [Parameter(Mandatory)] [ValidatePattern('^[\w.-]+/[\w.-]+$')] [string] $Repository,
    [Parameter(Mandatory)] [ValidateRange(1, [int]::MaxValue)] [int] $Number,
    [Parameter(Mandatory)] [string] $BodyPath
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
Import-Module (Join-Path $PSScriptRoot 'github-client.psm1')

$comment = Invoke-GhApi -Path "repos/$Repository/issues/$Number/comments" -Method POST `
    -Body @{ body = (Read-TextFile $BodyPath) } -Action "comment on #$Number of $Repository"

Write-Result ([ordered] @{ url = $comment.html_url })
