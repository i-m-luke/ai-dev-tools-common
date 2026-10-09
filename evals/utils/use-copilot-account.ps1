#Requires -Version 7
<#
.SYNOPSIS
Makes Copilot CLI run under the GitHub account named in `evals.config.json`, for this process.

.DESCRIPTION
Hands the account's GitHub CLI token to Copilot CLI via COPILOT_GITHUB_TOKEN, which beats every
other credential Copilot CLI knows, including GH_TOKEN. Child processes inherit it, so waza's
bundled Copilot CLI uses the account too. Does nothing when the config names no account; throws
when the account is not logged in to GitHub CLI.

.EXAMPLE
& (Join-Path $PSScriptRoot 'utils' 'use-copilot-account.ps1')
#>

$ErrorActionPreference = 'Stop'

$config = & (Join-Path $PSScriptRoot 'read-config.ps1')
if (-not $config.githubUser) { return }

$ghToken = (gh auth token --hostname github.com --user $config.githubUser 2>&1 | Out-String).Trim()
if ($LASTEXITCODE) { throw "No GitHub CLI token for '$($config.githubUser)' (run: gh auth login): $ghToken" }
$env:COPILOT_GITHUB_TOKEN = $ghToken
