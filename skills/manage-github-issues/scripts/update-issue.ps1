<#
.SYNOPSIS
Changes the title or the body of an issue or a pull request.

.DESCRIPTION
Replaces the title, the body or both; whatever is not passed stays as it is. To append to the body,
read it with get-item.ps1 first and pass the whole new body.

.PARAMETER Repository
The GitHub repository as `<owner>/<name>`.

.PARAMETER Number
The issue or pull request number.

.PARAMETER Title
Optional new title.

.PARAMETER BodyPath
Optional UTF-8 file holding the new body in Markdown.

.OUTPUTS
::result::{"number":<number>,"url":"<URL>"}

.NOTES
Exit codes:
- 0: the item is changed.
- 20: GitHub rejected the request, e.g. no issue or pull request has the number.

Stderr: the reason of the failure, followed by the output of GitHub CLI.
#>
param(
    [Parameter(Mandatory)] [ValidatePattern('^[\w.-]+/[\w.-]+$')] [string] $Repository,
    [Parameter(Mandatory)] [ValidateRange(1, [int]::MaxValue)] [int] $Number,
    [string] $Title,
    [string] $BodyPath
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
Import-Module (Join-Path $PSScriptRoot 'github-client.psm1')

$body = @{}
if ($Title) { $body.title = $Title }
if ($BodyPath) { $body.body = Read-TextFile $BodyPath }
if (-not $body.Count) { throw 'Pass -Title, -BodyPath or both.' }

$item = Invoke-GhApi -Path "repos/$Repository/issues/$Number" -Method PATCH -Body $body -Action "update #$Number of $Repository"

Write-Result ([ordered] @{ number = $item.number; url = $item.html_url })
