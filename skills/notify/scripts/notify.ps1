<#
.SYNOPSIS
Sends a message to the user's Telegram chat through a bot.

.DESCRIPTION
Reads the bot token and chat ID from the `notify` section of `agents.secrets.yaml`: the file given by
-SecretsPath, otherwise the first one found in the current git repository's root, then in
`~/.agents/`. Runs on Windows PowerShell 5.1 and PowerShell 7+.

Exit codes:
- 0: message sent.
- 1: config file 'agents.secrets.yaml' not found.
- 2: config file invalid (unreadable, no `notify` section, or empty `token`/`chatId`).
- 3: Telegram API or network error.

.PARAMETER Message
What to report; sent as `<WorkingFolderName>: <Message>`, truncated to Telegram's 4096-character limit.

.PARAMETER WorkingFolderName
Name of the repository or working folder the message is about.

.PARAMETER SecretsPath
Path to the config file; skips the lookup.

.EXAMPLE
./notify.ps1 -Message 'plan ready, waiting for approval.' -WorkingFolderName 'my-repo'
#>
param(
    [Parameter(Mandatory)] [string] $Message,
    [Parameter(Mandatory)] [string] $WorkingFolderName,
    [string] $SecretsPath
)

$ErrorActionPreference = 'Stop'

$secretsFileName = 'agents.secrets.yaml'
$maxMessageLength = 4096
$expectedStructure = @"
Expected structure:
notify:
  token: "<bot token>"
  chatId: "<chat ID>"
"@

function Fail([int] $Code, [string] $Message) {
    [Console]::Error.WriteLine($Message)
    exit $Code
}

function Get-GitRoot {
    if (-not (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)) { return $null }
    try { $root = & git rev-parse --show-toplevel 2>$null } catch { return $null }
    if ($root) { return ([string] $root).Trim() }
    return $null
}

function Get-SecretsCandidates {
    if ($SecretsPath) { return @($SecretsPath) }
    $candidates = @()
    $gitRoot = Get-GitRoot
    if ($gitRoot) { $candidates += Join-Path $gitRoot $secretsFileName }
    $userHome = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
    if ($userHome) { $candidates += Join-Path (Join-Path $userHome '.agents') $secretsFileName }
    return $candidates
}

function ConvertFrom-YamlScalar([string] $Value) {
    if ($Value -match '^"(.*)"$' -or $Value -match "^'(.*)'$") { return $Matches[1] }
    return ($Value -replace '\s+#.*$', '').Trim()
}

# Reads the keys of the top-level `notify` section; enough for the file's fixed two-level structure.
function Read-NotifySection([string] $Path) {
    $section = $null
    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
        if ($line -match '^\s*(#.*)?$') { continue }
        if ($line -match '^(\S[^:]*):') {
            if ($Matches[1].Trim() -eq 'notify') { $section = @{} }
            elseif ($null -ne $section) { break }
            continue
        }
        if ($null -ne $section -and $line -match '^\s+([^:\s]+)\s*:\s*(.*?)\s*$') {
            $section[$Matches[1]] = ConvertFrom-YamlScalar $Matches[2]
        }
    }
    return $section
}

$candidates = @(Get-SecretsCandidates)
$secretsFile = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $secretsFile) {
    Fail 1 "Config file '$secretsFileName' not found. Searched: $($candidates -join ', ')`n$expectedStructure"
}

try { $notify = Read-NotifySection $secretsFile }
catch { Fail 2 "Config file '$secretsFile' cannot be read: $($_.Exception.Message)" }
if ($null -eq $notify) { Fail 2 "Config file '$secretsFile' has no 'notify' section.`n$expectedStructure" }
$missing = @('token', 'chatId' | Where-Object { -not $notify[$_] })
if ($missing) { Fail 2 "Config file '$secretsFile' has an empty or missing 'notify.$($missing -join "', 'notify.")'.`n$expectedStructure" }

$text = "${WorkingFolderName}: $Message"
if ($text.Length -gt $maxMessageLength) { $text = $text.Substring(0, $maxMessageLength - 1) + [char] 0x2026 }

$body = ConvertTo-Json -Compress @{ chat_id = $notify['chatId']; text = $text }
try {
    $response = Invoke-RestMethod -Method Post `
        -Uri "https://api.telegram.org/bot$($notify['token'])/sendMessage" `
        -ContentType 'application/json; charset=utf-8' `
        -Body ([Text.Encoding]::UTF8.GetBytes($body))
}
catch {
    $detail = if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
    Fail 3 "Telegram API or network error: $detail"
}
if (-not $response.ok) { Fail 3 "Telegram API error: $($response.description)" }

Write-Output 'Message sent.'
exit 0
