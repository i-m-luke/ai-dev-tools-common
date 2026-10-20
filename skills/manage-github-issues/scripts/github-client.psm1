<#
.SYNOPSIS
Shared helpers of the manage-github-issues scripts: calling GitHub CLI, emitting the result and
ending with an expected failure. Not a script to run; the scripts import it.
#>

$script:Utf8 = New-Object Text.UTF8Encoding $false

function Stop-WithError {
    param([Parameter(Mandatory)] [int] $Code, [Parameter(Mandatory)] [string] $Message)
    [Console]::Error.WriteLine($Message)
    exit $Code
}

function Write-Result {
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [object] $Value)
    [Console]::Out.WriteLine('::result::' + (ConvertTo-Json -InputObject $Value -Compress -Depth 10))
}

function Invoke-Gh {
    <# Runs gh; returns its exit code, stdout and stderr without stopping on a failure. #>
    param([Parameter(Mandatory)] [string[]] $Arguments, [string] $InputText)

    # Native stderr arrives as error records; 'Stop' would turn the first one into an exception.
    $ErrorActionPreference = 'Continue'
    $OutputEncoding = $script:Utf8
    $lines = if ($PSBoundParameters.ContainsKey('InputText')) {
        $InputText | & gh @Arguments 2>&1
    } else {
        & gh @Arguments 2>&1
    }
    $exitCode = $LASTEXITCODE

    $stdout = New-Object Collections.Generic.List[string]
    $stderr = New-Object Collections.Generic.List[string]
    foreach ($line in $lines) {
        if ($line -is [Management.Automation.ErrorRecord]) { $stderr.Add($line.ToString()) } else { $stdout.Add([string] $line) }
    }
    [pscustomobject] @{ ExitCode = $exitCode; Stdout = ($stdout -join "`n"); Stderr = ($stderr -join "`n") }
}

function Assert-GhSuccess {
    <# Ends the script with exit code 2 when the gh call failed. #>
    param([Parameter(Mandatory)] [object] $Call, [Parameter(Mandatory)] [string] $Action)
    if ($Call.ExitCode -ne 0) { Stop-WithError 2 "Cannot $Action; gh failed with exit code $($Call.ExitCode):`n$($Call.Stderr)" }
}

function Invoke-GhApi {
    <#
    Calls the GitHub REST API through `gh api` and returns the parsed JSON response.
    A failed call ends the script with exit code 2; with -NotFoundCode, an HTTP 404 ends it with that
    code and -NotFoundMessage instead; with -IgnoreNotFound, an HTTP 404 returns nothing.
    #>
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Action,
        [ValidateSet('GET', 'POST', 'PATCH', 'DELETE')] [string] $Method = 'GET',
        [hashtable] $Body,
        [int] $NotFoundCode,
        [string] $NotFoundMessage,
        [switch] $IgnoreNotFound
    )

    $arguments = @('api', '--method', $Method, $Path)
    $call = if ($Body) {
        Invoke-Gh -Arguments ($arguments + @('--input', '-')) -InputText (ConvertTo-Json -InputObject $Body -Compress -Depth 10)
    } else {
        Invoke-Gh -Arguments $arguments
    }

    if ($call.ExitCode -ne 0 -and $call.Stderr -match 'HTTP 404') {
        if ($IgnoreNotFound) { return }
        if ($NotFoundCode) { Stop-WithError $NotFoundCode "$NotFoundMessage`n$($call.Stderr)" }
    }
    Assert-GhSuccess $call $Action
    if ($call.Stdout.Trim()) { $call.Stdout | ConvertFrom-Json }
}

function Get-GhApiPages {
    <# Returns every item of a paginated REST list, one at a time, up to -Limit items. #>
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Action,
        [int] $NotFoundCode,
        [string] $NotFoundMessage,
        [int] $Limit = [int]::MaxValue
    )

    $separator = if ($Path.Contains('?')) { '&' } else { '?' }
    $count = 0
    for ($page = 1; ; $page++) {
        $apiArgs = @{ Path = "$Path${separator}per_page=100&page=$page"; Action = $Action }
        if ($NotFoundCode) { $apiArgs.NotFoundCode = $NotFoundCode; $apiArgs.NotFoundMessage = $NotFoundMessage }
        # Windows PowerShell returns a JSON array as one object; foreach unrolls it in both editions.
        $items = @(foreach ($item in (Invoke-GhApi @apiArgs)) { $item })
        foreach ($item in $items) {
            if ($count -ge $Limit) { return }
            $item
            $count++
        }
        if ($items.Count -lt 100) { return }
    }
}

function Read-TextFile {
    param([Parameter(Mandatory)] [string] $Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "The file '$Path' does not exist." }
    [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).ProviderPath, $script:Utf8)
}

function Split-List {
    <# Splits a comma-separated list into its trimmed, non-empty items. #>
    param([string] $List)
    @(foreach ($item in ($List -split ',')) { if ($item.Trim()) { $item.Trim() } })
}

function ConvertTo-Comment {
    param([Parameter(Mandatory)] [object] $Comment)
    [ordered] @{ author = $Comment.user.login; body = $Comment.body; createdAt = $Comment.created_at }
}

function Get-Names {
    <# Maps REST labels or users to the value of one property, e.g. their names or logins. #>
    param([object] $Items, [Parameter(Mandatory)] [string] $Property)
    @(foreach ($item in $Items) { $item.$Property })
}

Export-ModuleMember -Function Stop-WithError, Write-Result, Invoke-Gh, Assert-GhSuccess, Invoke-GhApi,
    Get-GhApiPages, Read-TextFile, Split-List, ConvertTo-Comment, Get-Names
