<#
.SYNOPSIS
Creates an issue.

.DESCRIPTION
Creates an issue with a title, a Markdown body read from a file, and optional labels; GitHub
creates a label that does not exist yet.

.PARAMETER Repository
The GitHub repository as `<owner>/<name>`.

.PARAMETER Title
The issue title.

.PARAMETER BodyPath
A UTF-8 file holding the issue body in Markdown.

.PARAMETER Label
Optional comma-separated labels to apply, e.g. `bug,needs-triage`.

.OUTPUTS
::result::{"number":<issue number>,"url":"<issue URL>"}

.NOTES
Exit codes:
- 0: the issue is created.
- 2: GitHub rejected the request.

Stderr: the reason of the failure, followed by the output of GitHub CLI.
#>
param(
    [Parameter(Mandatory)] [ValidatePattern('^[\w.-]+/[\w.-]+$')] [string] $Repository,
    [Parameter(Mandatory)] [string] $Title,
    [Parameter(Mandatory)] [string] $BodyPath,
    [string] $Label
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
Import-Module (Join-Path $PSScriptRoot 'github-client.psm1')

$body = @{ title = $Title; body = (Read-TextFile $BodyPath) }
$labels = @(Split-List $Label)
if ($labels.Count) { $body.labels = $labels }

$issue = Invoke-GhApi -Path "repos/$Repository/issues" -Method POST -Body $body -Action "create an issue in $Repository"

Write-Result ([ordered] @{ number = $issue.number; url = $issue.html_url })
