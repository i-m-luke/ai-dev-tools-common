# Shared helpers of the manage-github-issues script tests; dot-source it in BeforeAll.

$script:scriptsDir = Join-Path $PSScriptRoot '..' '..' '..' 'skills' 'manage-github-issues' 'scripts'
$script:stubDir = Join-Path $PSScriptRoot 'gh-stub'
$script:repo = 'owner/name'

# Makes the stub answer by these rules: hashtables with `match` (regex on the space-joined gh
# arguments), optional `stdout` (a string, or an object sent as JSON), `stderr` and `exit` (0 by default).
function Set-GhStub([object[]] $Rules) {
    $env:GH_STUB_RULES = Join-Path $TestDrive "gh-rules-$([guid]::NewGuid()).json"
    $env:GH_STUB_LOG = Join-Path $TestDrive "gh-log-$([guid]::NewGuid()).jsonl"
    $normalized = @(foreach ($rule in $Rules) {
            $stdout = $rule.stdout
            if ($null -ne $stdout -and $stdout -isnot [string]) { $stdout = ConvertTo-Json -InputObject $stdout -Compress -Depth 10 }
            [ordered] @{ match = $rule.match; stdout = $stdout; stderr = $rule.stderr; exit = [int] $rule.exit }
        })
    Set-Content -LiteralPath $env:GH_STUB_RULES -Value (ConvertTo-Json -InputObject $normalized -Depth 5) -Encoding utf8
}

# The calls the scripts made to the stub: objects with `args` (array) and `stdin` (string or null).
function Get-GhCalls {
    if (Test-Path -LiteralPath $env:GH_STUB_LOG) {
        Get-Content -LiteralPath $env:GH_STUB_LOG -Encoding utf8 | ForEach-Object { $_ | ConvertFrom-Json }
    }
}

# The JSON body of the single call whose arguments match the regex.
function Get-GhBody([string] $Match) {
    $calls = @(Get-GhCalls | Where-Object { ($_.args -join ' ') -match $Match })
    $calls.Count | Should -Be 1 -Because "one gh call matches '$Match'"
    $calls[0].stdin | ConvertFrom-Json
}

# Runs a script of the skill as a child process with the stub first on PATH; -WithoutGh leaves gh off PATH.
function Invoke-SkillScript([string] $Name, [hashtable] $Parameters = @{}, [string] $Shell = 'pwsh', [switch] $WithoutGh) {
    $arguments = foreach ($key in $Parameters.Keys) { "-$key"; "$($Parameters[$key])" }
    $stderrPath = Join-Path $TestDrive "stderr-$([guid]::NewGuid()).txt"
    $shellPath = (Get-Command $Shell -CommandType Application | Select-Object -First 1).Source
    $originalPath = $env:PATH
    $env:PATH = if ($WithoutGh) { (New-Item -ItemType Directory -Path (Join-Path $TestDrive "empty-$([guid]::NewGuid())")).FullName }
    else { $script:stubDir + [IO.Path]::PathSeparator + $originalPath }
    try {
        $stdout = & $shellPath -NoProfile -File (Join-Path $script:scriptsDir "$Name.ps1") @arguments 2>$stderrPath
        $exitCode = $LASTEXITCODE
    } finally {
        $env:PATH = $originalPath
    }

    $resultLines = @($stdout | Where-Object { $_ -like '::result::*' })
    [pscustomobject] @{
        ExitCode    = $exitCode
        Stdout      = $stdout
        Stderr      = (Get-Content -Raw -LiteralPath $stderrPath)
        ResultLines = $resultLines.Count
        Result      = if ($resultLines.Count -eq 1) { $resultLines[0].Substring('::result::'.Length) | ConvertFrom-Json -NoEnumerate }
    }
}

# Writes UTF-8 text to a new file and returns its path, for the -BodyPath parameters.
function New-TextFile([string] $Text) {
    $path = Join-Path $TestDrive "text-$([guid]::NewGuid()).md"
    [IO.File]::WriteAllText($path, $Text, [Text.UTF8Encoding]::new($false))
    $path
}

# A REST issue as GitHub returns it; -PullRequest makes it a pull request.
function New-RestIssue {
    param(
        [int] $Number,
        [string] $State = 'open',
        [string[]] $Labels = @(),
        [string[]] $Assignees = @(),
        [int] $OpenBlockers = 0,
        [switch] $PullRequest
    )
    $issue = [ordered] @{
        id                         = 1000 + $Number
        number                     = $Number
        title                      = "Title $Number"
        state                      = $State
        html_url                   = "https://github.com/$script:repo/issues/$Number"
        user                       = @{ login = 'author' }
        body                       = "Body $Number"
        labels                     = @($Labels | ForEach-Object { @{ name = $_ } })
        assignees                  = @($Assignees | ForEach-Object { @{ login = $_ } })
        issue_dependencies_summary = @{ blocked_by = $OpenBlockers; total_blocked_by = $OpenBlockers }
    }
    if ($PullRequest) { $issue.pull_request = @{ url = "https://api.github.com/repos/$script:repo/pulls/$Number" } }
    $issue
}

# The regex matching a gh api call: method, then the exact path, optionally followed by a query string.
function Get-ApiMatch([string] $Method, [string] $Path) {
    "^api --method $Method $([regex]::Escape($Path))(\?\S*)?( --input -)?$"
}

$script:notFound = @{ stderr = 'gh: Not Found (HTTP 404)'; exit = 1 }
