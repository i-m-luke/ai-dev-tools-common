<#
.SYNOPSIS
Checks that the .NET SDK and dotnet-script, which win-app-spy's scripts run on, are installed.

.DESCRIPTION
Logs the newest installed .NET SDK version and the dotnet-script version. Takes no parameters.
Runs on Windows PowerShell 5.1 and PowerShell 7+.

.OUTPUTS
None.

.NOTES
Exit codes:
- 0: both prerequisites are installed.
- 2: a prerequisite is missing.

Stderr: on exit 2, how to install each missing prerequisite.
#>

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

# Returns the non-empty output lines of a successful dotnet call, or $null.
function Invoke-Dotnet([string[]] $Arguments) {
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { return $null }
    # Windows PowerShell 5.1 turns redirected native stderr into terminating errors under 'Stop'.
    $ErrorActionPreference = 'Continue'
    $lines = @(& dotnet @Arguments 2>$null | Where-Object { $_ -match '\S' })
    if ($LASTEXITCODE -ne 0 -or $lines.Count -eq 0) { return $null }
    return , $lines
}

# dotnet lists the SDKs in ascending version order.
$sdks = Invoke-Dotnet '--list-sdks'
$sdkVersion = if ($sdks) { ([string] $sdks[-1] -split ' ')[0] } else { $null }
$scriptOutput = Invoke-Dotnet 'script', '--version'
$scriptVersion = if ($scriptOutput) { ([string] $scriptOutput[0]).Trim() } else { $null }

$instructions = @()
if (-not $sdkVersion) {
    $instructions += @"
The .NET SDK is missing. Install it from https://dotnet.microsoft.com/download
or run: winget install Microsoft.DotNet.SDK.10
"@
}
if (-not $scriptVersion) {
    $instructions += @"
dotnet-script is missing. Once the .NET SDK is installed, run: dotnet tool install -g dotnet-script
Then make sure the .NET tools folder (%USERPROFILE%\.dotnet\tools) is on the PATH and open a new terminal.
"@
}
if ($instructions) {
    [Console]::Error.WriteLine(($instructions -join "`n`n"))
    exit 2
}

Write-Host ".NET SDK: $sdkVersion"
Write-Host "dotnet-script: $scriptVersion"
exit 0
