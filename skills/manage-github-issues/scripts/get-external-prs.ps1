<#
.SYNOPSIS
Lists the open pull requests of external contributors, with their comments.

.DESCRIPTION
Lists the open pull requests whose author is not an owner, member or collaborator of the
repository — author association CONTRIBUTOR, FIRST_TIME_CONTRIBUTOR, FIRST_TIMER or NONE.

.PARAMETER Repository
The GitHub repository as `<owner>/<name>`.

.OUTPUTS
::result::[{"number":<number>,"title":"…","url":"…","body":"<Markdown>","author":"<login>",
"authorAssociation":"…","labels":["…"],"comments":[{"author":"<login>","body":"<Markdown>","createdAt":"<ISO 8601>"}]}]

.NOTES
Exit codes:
- 0: the pull requests are listed; the list may be empty.
- 20: GitHub rejected the request.

Stderr: the reason of the failure, followed by the output of GitHub CLI.
#>
param(
    [Parameter(Mandatory)] [ValidatePattern('^[\w.-]+/[\w.-]+$')] [string] $Repository
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
Import-Module (Join-Path $PSScriptRoot 'github-client.psm1')

$external = 'CONTRIBUTOR', 'FIRST_TIME_CONTRIBUTOR', 'FIRST_TIMER', 'NONE'
$pulls = @(Get-GhApiPages -Path "repos/$Repository/pulls?state=open" -Action "list the pull requests of $Repository" |
        Where-Object { $external -contains $_.author_association })

$result = @(foreach ($pull in $pulls) {
        [ordered] @{
            number            = $pull.number
            title             = $pull.title
            url               = $pull.html_url
            body              = $pull.body
            author            = $pull.user.login
            authorAssociation = $pull.author_association
            labels            = @(Get-Names $pull.labels 'name')
            comments          = @(Get-GhApiPages -Path "repos/$Repository/issues/$($pull.number)/comments" `
                    -Action "read the comments of #$($pull.number)" | ForEach-Object { ConvertTo-Comment $_ })
        }
    })

Write-Result $result
