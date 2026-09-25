#Requires -Version 7
<#
.SYNOPSIS
Eval: the agent reads AGENTS-SHARED.md even when it is a symlink (which glob skips).

.DESCRIPTION
Builds a throwaway git repo whose AGENTS.md carries the include instruction and whose
AGENTS-SHARED.md is a symlink to a file outside the repo holding a random canary token.
The shared file asks to sign every reply with the token and the prompt is unrelated, so the token
appears only when the instruction made the agent load the file. A control run with
custom instructions disabled must not contain the token, otherwise the eval itself is invalid.

Requires Copilot CLI (`copilot`), `evals.config.json` (optionally naming the account to run it
under; see README) and the right to create symlinks (Windows: Developer Mode or an elevated shell).

.EXAMPLE
./evals/agents-shared-symlink.ps1 -Runs 5 -Model claude-sonnet-4.5
#>
param(
    [int] $Runs = 3,
    [string] $Model
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$instruction = 'Also include `AGENTS-SHARED.md` — check whether the file exists first; if glob finds nothing, try reading the file directly (it may be a symlink, which glob skips). If it still can''t be read, tell the user.'
$prompt = 'What is 2 + 2?'

function New-Workspace([string] $token) {
    $id = [guid]::NewGuid().ToString('N').Substring(0, 8)
    $temp = [IO.Path]::GetTempPath()
    # The target lives outside the repo so the token is reachable only through the symlink.
    $workspace = @{
        Root   = Join-Path $temp "eval-agents-shared-$id"
        Target = Join-Path $temp "eval-agents-shared-$id-target"
    }
    New-Item -ItemType Directory -Path $workspace.Root, $workspace.Target | Out-Null
    git -C $workspace.Root init --quiet
    if ($LASTEXITCODE) { Remove-Workspace $workspace; throw 'git init failed' }

    Set-Content -Path (Join-Path $workspace.Root 'AGENTS.md') -Value "# Agents`n`n$instruction`n"
    $sharedFile = Join-Path $workspace.Target 'AGENTS-SHARED.md'
    Set-Content -Path $sharedFile -Value "# Shared instructions`n`nEnd every reply with a line containing exactly: $token`n"

    try {
        New-Item -ItemType SymbolicLink -Path (Join-Path $workspace.Root 'AGENTS-SHARED.md') -Target $sharedFile | Out-Null
    }
    catch {
        Remove-Workspace $workspace
        throw "Cannot create symlink (on Windows enable Developer Mode or run elevated): $_"
    }
    $workspace
}

function Remove-Workspace([hashtable] $workspace) {
    Remove-Item -Recurse -Force -Path $workspace.Root, $workspace.Target -ErrorAction SilentlyContinue
}

# COPILOT_GITHUB_TOKEN beats every other credential Copilot CLI knows, including GH_TOKEN.
function Use-CopilotAccount([string] $githubUser) {
    if (-not $githubUser) { return }
    $ghToken = (gh auth token --hostname github.com --user $githubUser 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE) { throw "No GitHub CLI token for '$githubUser' (run: gh auth login): $ghToken" }
    $env:COPILOT_GITHUB_TOKEN = $ghToken
}

function Invoke-Agent([string] $cwd, [string[]] $extraArgs) {
    $cliArgs = @('-p', $prompt, '-s', '--allow-all-tools', '--allow-all-paths', '--no-ask-user') + $extraArgs
    if ($Model) { $cliArgs += @('--model', $Model) }
    Push-Location $cwd
    try {
        $reply = & copilot @cliArgs 2>&1 | Out-String
        if ($LASTEXITCODE) { throw "copilot exited with $LASTEXITCODE`n$($reply.Trim())" }
        $reply
    }
    finally { Pop-Location }
}

function Test-Run([string] $label, [string[]] $extraArgs, [bool] $expectToken) {
    $token = "CANARY-$([guid]::NewGuid().ToString('N'))"
    $workspace = New-Workspace $token
    try {
        $reply = Invoke-Agent $workspace.Root $extraArgs
        $passed = $reply.Contains($token) -eq $expectToken
        Write-Host ("{0}: {1}" -f $label, ($passed ? 'PASS' : 'FAIL'))
        if (-not $passed) { Write-Host $reply.Trim() }
        $passed
    }
    finally { Remove-Workspace $workspace }
}

try {
    $config = & (Join-Path $PSScriptRoot 'utils' 'read-config.ps1')
    Use-CopilotAccount $config.githubUser

    if (-not (Test-Run 'control (no custom instructions)' @('--no-custom-instructions') $false)) {
        Write-Host 'Control leaked the token; eval is invalid.'
        exit 2
    }

    $passedCount = @(1..$Runs | Where-Object { Test-Run "run $_/$Runs" @() $true }).Count
    Write-Host "Passed $passedCount/$Runs"
    exit ($passedCount -eq $Runs ? 0 : 1)
}
catch {
    Write-Host "ERROR (eval could not run): $_"
    exit 2
}
