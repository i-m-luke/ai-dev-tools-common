<#
.SYNOPSIS
Reads an issue or a pull request with its comments.

.DESCRIPTION
Issues and pull requests share one number space, so the number alone decides which one is read;
`kind` in the result tells which it was. A pull request comes with its diff.

.PARAMETER Repository
The GitHub repository as `<owner>/<name>`.

.PARAMETER Number
The issue or pull request number.

.OUTPUTS
::result::{"kind":"issue|pr","number":<number>,"title":"…","state":"open|closed","url":"…",
"author":"<login>","body":"<Markdown>","labels":["…"],"assignees":["<login>"],
"comments":[{"author":"<login>","body":"<Markdown>","createdAt":"<ISO 8601>"}],
"diff":"<unified diff; pull requests only>"}

.NOTES
Exit codes:
- 0: the item is read.
- 2: GitHub rejected the request, e.g. no issue or pull request has the number.

Stderr: the reason of the failure, followed by the output of GitHub CLI.
#>
param(
    [Parameter(Mandatory)] [ValidatePattern('^[\w.-]+/[\w.-]+$')] [string] $Repository,
    [Parameter(Mandatory)] [ValidateRange(1, [int]::MaxValue)] [int] $Number
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
Import-Module (Join-Path $PSScriptRoot 'github-client.psm1')

$item = Invoke-GhApi -Path "repos/$Repository/issues/$Number" -Action "read #$Number of $Repository"
$comments = @(Get-GhApiPages -Path "repos/$Repository/issues/$Number/comments" -Action "read the comments of #$Number" |
        ForEach-Object { ConvertTo-Comment $_ })

$result = [ordered] @{
    kind      = if ($item.pull_request) { 'pr' } else { 'issue' }
    number    = $item.number
    title     = $item.title
    state     = $item.state
    url       = $item.html_url
    author    = $item.user.login
    body      = $item.body
    labels    = @(Get-Names $item.labels 'name')
    assignees = @(Get-Names $item.assignees 'login')
    comments  = $comments
}

if ($item.pull_request) {
    $diff = Invoke-Gh -Arguments @('pr', 'diff', "$Number", '--repo', $Repository)
    Assert-GhSuccess $diff "read the diff of pull request #$Number"
    $result.diff = $diff.Stdout
}

Write-Result $result
