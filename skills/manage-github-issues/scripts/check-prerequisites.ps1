<#
.SYNOPSIS
Checks that GitHub CLI can manage the issues of a repository.

.DESCRIPTION
Checks that GitHub CLI (gh) is installed, that it is logged in to github.com, and that the
repository is accessible and has issues enabled.

.PARAMETER Repository
The GitHub repository as `<owner>/<name>`.

.OUTPUTS
None.

.NOTES
Exit codes:
- 0: every prerequisite holds.
- 2: GitHub CLI is not installed.
- 3: GitHub CLI is not logged in to github.com.
- 4: the repository does not exist, is not accessible to the logged-in account, or has issues disabled.

Stderr: which prerequisite failed and how to fix it, followed by the output of GitHub CLI.
#>
param(
    [Parameter(Mandatory)] [ValidatePattern('^[\w.-]+/[\w.-]+$')] [string] $Repository
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
Import-Module (Join-Path $PSScriptRoot 'github-client.psm1')

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Stop-WithError 2 'GitHub CLI (gh) is not installed; install it from https://cli.github.com and make sure gh is on PATH.'
}

$auth = Invoke-Gh -Arguments @('auth', 'status', '--hostname', 'github.com')
if ($auth.ExitCode -ne 0) {
    Stop-WithError 3 "GitHub CLI is not logged in to github.com; run 'gh auth login'.`n$($auth.Stderr)"
}

$repo = Invoke-Gh -Arguments @('api', "repos/$Repository")
if ($repo.ExitCode -ne 0) {
    Stop-WithError 4 "The repository $Repository does not exist or is not accessible to the logged-in account.`n$($repo.Stderr)"
}
if (-not ($repo.Stdout | ConvertFrom-Json).has_issues) {
    Stop-WithError 4 "The repository $Repository has issues disabled; enable them in its settings."
}

Write-Host "GitHub CLI can manage the issues of $Repository."
