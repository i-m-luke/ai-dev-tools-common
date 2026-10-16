# Shared helpers for the win-app-spy script tests; dot-source it in BeforeAll.

# Copies the skill's scripts into a working folder under $TestDrive, as the skill does, and makes it
# the folder Invoke-Spy runs in; the copy also keeps session.json out of the repo.
function Initialize-SpyWorkingFolder {
    $script:spyWorkingFolder = Join-Path $TestDrive 'working-folder'
    New-Item -ItemType Directory -Path $script:spyWorkingFolder -Force | Out-Null
    Copy-Item -Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'win-app-spy' 'scripts' '*') -Destination $script:spyWorkingFolder -Recurse -Force
    $script:spyOriginalEncoding = [Console]::OutputEncoding
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
}

function Restore-SpyConsoleEncoding { [Console]::OutputEncoding = $script:spyOriginalEncoding }

# Writes the request (a JSON string or a hashtable) to req.json, runs the main script on it and parses the JSON it prints.
function Invoke-Spy {
    param($Request)
    if ($Request -isnot [string]) { $Request = $Request | ConvertTo-Json -Depth 10 }
    Set-Content -LiteralPath (Join-Path $script:spyWorkingFolder 'req.json') -Value $Request -Encoding utf8
    Push-Location $script:spyWorkingFolder
    try { $stdout = & dotnet script (Join-Path $script:spyWorkingFolder 'win-app-spy.csx') -- req.json 2>$null | Out-String }
    finally { Pop-Location }
    [pscustomobject] @{ ExitCode = $LASTEXITCODE; Raw = $stdout; Json = $stdout | ConvertFrom-Json -AsHashtable }
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
