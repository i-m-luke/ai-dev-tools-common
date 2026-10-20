# Shared helpers for the win-app-spy script tests; dot-source it in BeforeAll.

$script:spyScript = Join-Path $PSScriptRoot '..' '..' '..' 'skills' 'win-app-spy' 'scripts' 'spy.csx'

# Makes a working folder under $TestDrive the folder Invoke-Spy sends its requests from, so
# session.json and screenshots stay out of the repo.
function Initialize-SpyWorkingFolder {
    $script:spyWorkingFolder = Join-Path $TestDrive 'working-folder'
    New-Item -ItemType Directory -Path $script:spyWorkingFolder -Force | Out-Null
    $script:spyOriginalEncoding = [Console]::OutputEncoding
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
}

function Restore-SpyConsoleEncoding { [Console]::OutputEncoding = $script:spyOriginalEncoding }

# Runs a script with the arguments and parses its outcome: Json is the result on exit 0, otherwise
# @{ error = <the error object on stderr> }; ResultLines counts the ::result:: lines on stdout.
function Invoke-SpyScript {
    param([string] $Script = $script:spyScript, [string[]] $Arguments = @())
    $output = & dotnet script $Script -- @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $stderr = ($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { $_.ToString() }) -join "`n"
    $stdout = @($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { "$_" })
    $results = @($stdout | Where-Object { $_ -like '::result::*' })
    $json = if ($exitCode -eq 0) {
        if ($results.Count -eq 1) { $results[0].Substring('::result::'.Length) | ConvertFrom-Json -AsHashtable }
    }
    elseif ($stderr) {
        try { @{ error = $stderr | ConvertFrom-Json -AsHashtable } } catch { $null }
    }
    [pscustomobject] @{
        ExitCode    = $exitCode
        Raw         = (@($stdout) + $stderr) -join "`n"
        Stdout      = $stdout
        ResultLines = $results.Count
        Json        = $json
    }
}

# Writes the request (a JSON string or a hashtable) to req.json in the working folder and runs spy.csx on it.
function Invoke-Spy {
    param($Request)
    if ($Request -isnot [string]) { $Request = $Request | ConvertTo-Json -Depth 10 }
    $path = Join-Path $script:spyWorkingFolder 'req.json'
    Set-Content -LiteralPath $path -Value $Request -Encoding utf8
    Invoke-SpyScript -Arguments '--request-path', $path
}

# Parallel runs share one desktop: hold this lock while an app the tests start is open.
function Enter-GuiLock {
    $lock = Join-Path $env:TEMP 'win-app-spy-gui.lock'
    while ($true) {
        try { New-Item -ItemType Directory -Path $lock -ErrorAction Stop | Out-Null; return }
        catch {
            $held = Get-Item -LiteralPath $lock -ErrorAction SilentlyContinue
            if ($held -and $held.CreationTime -lt (Get-Date).AddMinutes(-15)) { Remove-Item -LiteralPath $lock -Recurse -Force -ErrorAction SilentlyContinue }
            Start-Sleep -Seconds 5
        }
    }
}

function Exit-GuiLock { Remove-Item -LiteralPath (Join-Path $env:TEMP 'win-app-spy-gui.lock') -Recurse -Force -ErrorAction SilentlyContinue }

# Starts fixture-app.ps1 and waits until its windows are shown; returns its process.
# -TriggerFolder adds its Waiter window (see fixture-waiter.ps1).
function Start-FixtureApp {
    param([switch] $WithActForm, [string] $TriggerFolder)
    $ready = Join-Path $TestDrive "fixture-ready-$([guid]::NewGuid()).txt"
    $fixture = Join-Path $PSScriptRoot 'fixture-app.ps1'
    $arguments = @('-NoProfile', '-File', "`"$fixture`"", '-ReadyFile', "`"$ready`"")
    if ($WithActForm) { $arguments += '-WithActForm' }
    if ($TriggerFolder) { $arguments += '-TriggerFolder', "`"$TriggerFolder`"" }
    $process = Start-Process (Join-Path $PSHOME 'pwsh.exe') -ArgumentList $arguments -WindowStyle Hidden -PassThru
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while (-not (Test-Path -LiteralPath $ready)) {
        if ($process.HasExited -or $clock.Elapsed.TotalSeconds -gt 60) { throw 'The fixture app did not start.' }
        Start-Sleep -Milliseconds 200
    }
    $process
}
