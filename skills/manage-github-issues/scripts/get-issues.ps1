<#
.SYNOPSIS
Lists issues with their comments.

.DESCRIPTION
Lists the issues — never pull requests — in a state, optionally only those carrying every given
label, newest first.

.PARAMETER Repository
The GitHub repository as `<owner>/<name>`.

.PARAMETER State
`open` (default), `closed` or `all`.

.PARAMETER Label
Optional comma-separated labels; an issue is listed only when it carries all of them.

.PARAMETER Limit
The most issues to list; 100 by default.

.OUTPUTS
::result::[{"number":<number>,"title":"…","url":"…","body":"<Markdown>","labels":["…"],
"assignees":["<login>"],"comments":[{"author":"<login>","body":"<Markdown>","createdAt":"<ISO 8601>"}]}]

.NOTES
Exit codes:
- 0: the issues are listed; the list may be empty.
- 2: GitHub rejected the request.

Stderr: the reason of the failure, followed by the output of GitHub CLI.
#>
param(
    [Parameter(Mandatory)] [ValidatePattern('^[\w.-]+/[\w.-]+$')] [string] $Repository,
    [ValidateSet('open', 'closed', 'all')] [string] $State = 'open',
    [string] $Label,
    [ValidateRange(1, [int]::MaxValue)] [int] $Limit = 100
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
Import-Module (Join-Path $PSScriptRoot 'github-client.psm1')

$arguments = @('issue', 'list', '--repo', $Repository, '--state', $State, '--limit', "$Limit",
    '--json', 'number,title,url,body,labels,assignees,comments')
foreach ($name in (Split-List $Label)) { $arguments += @('--label', $name) }

$call = Invoke-Gh -Arguments $arguments
Assert-GhSuccess $call "list the issues of $Repository"

$issues = @(foreach ($issue in ($call.Stdout | ConvertFrom-Json)) {
        [ordered] @{
            number    = $issue.number
            title     = $issue.title
            url       = $issue.url
            body      = $issue.body
            labels    = @(Get-Names $issue.labels 'name')
            assignees = @(Get-Names $issue.assignees 'login')
            comments  = @(foreach ($comment in $issue.comments) {
                    [ordered] @{ author = $comment.author.login; body = $comment.body; createdAt = $comment.createdAt }
                })
        }
    })

Write-Result $issues
