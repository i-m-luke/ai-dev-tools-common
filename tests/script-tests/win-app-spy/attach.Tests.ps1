# Covers attach.csx and the `app` field every request may send, through the JSON contract of
# win-app-spy.csx. GUI runs use a fixture app with a unique process name and window title, so they
# never touch the user's windows; they skip in CI, which has no desktop.
BeforeDiscovery {
    $script:noDotnetScript = -not (Get-Command dotnet-script -ErrorAction SilentlyContinue)
}

BeforeAll {
    # Scripts run from a copy, as in the skill's working folder; the copy also keeps session.json out of the repo.
    $script:workingFolder = Join-Path $TestDrive 'working-folder'
    New-Item -ItemType Directory -Path $script:workingFolder | Out-Null
    Copy-Item -Path (Join-Path $PSScriptRoot '..' '..' '..' 'skills' 'win-app-spy' 'scripts' '*') -Destination $script:workingFolder -Recurse
    $script:mainScript = Join-Path $script:workingFolder 'win-app-spy.csx'
    $script:originalEncoding = [Console]::OutputEncoding
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

    # Writes the request to req.json, runs the main script on it and parses the JSON it prints.
    function Invoke-Spy {
        param([string] $Request)
        Set-Content -LiteralPath (Join-Path $script:workingFolder 'req.json') -Value $Request -Encoding utf8
        Push-Location $script:workingFolder
        try { $stdout = & dotnet script $script:mainScript -- req.json 2>$null | Out-String }
        finally { Pop-Location }
        [pscustomobject] @{ ExitCode = $LASTEXITCODE; Raw = $stdout; Json = $stdout | ConvertFrom-Json -AsHashtable }
    }
}

AfterAll { [Console]::OutputEncoding = $script:originalEncoding }

Describe 'attach' -Skip:$noDotnetScript {
    BeforeEach { Remove-Item -LiteralPath (Join-Path $script:workingFolder 'session.json') -ErrorAction SilentlyContinue }

    It 'answers APP_NOT_FOUND when <case>' -ForEach @(
        @{ case = 'no process has the pid'; app = @{ pid = 2147483000 } }
        @{ case = 'no process has the name'; app = @{ process = "win-app-spy-no-such-app-$([guid]::NewGuid())" } }
        @{ case = 'no window has the title'; app = @{ title = "win-app-spy-no-such-title-$([guid]::NewGuid())" } }
    ) {
        $result = Invoke-Spy (@{ command = 'attach'; app = $app } | ConvertTo-Json)

        $result.ExitCode | Should -Be 1
        $result.Json.error.code | Should -Be 'APP_NOT_FOUND'
        $result.Json.error.message | Should -Not -BeNullOrEmpty
    }

    It 'answers INVALID_REQUEST when <case>' -ForEach @(
        @{ case = 'app is missing'; request = '{ "command": "attach" }' }
        @{ case = 'app holds no selector'; request = '{ "command": "attach", "app": {} }' }
        @{ case = 'app holds two selectors'; request = '{ "command": "attach", "app": { "pid": 1, "title": "x" } }' }
        @{ case = 'the pid is not an integer'; request = '{ "command": "attach", "app": { "pid": "1" } }' }
    ) {
        $result = Invoke-Spy $request

        $result.ExitCode | Should -Be 1
        $result.Json.error.code | Should -Be 'INVALID_REQUEST'
    }

    Context 'with running apps' -Skip:([bool] $env:CI) {
        BeforeAll {
            # A window that never takes focus, so the tests don't disturb whoever uses the desktop.
            $source = Join-Path $TestDrive 'fixture.cs'
            Set-Content -LiteralPath $source -Value @'
using System.Windows.Forms;
class Fixture : Form
{
    protected override bool ShowWithoutActivation { get { return true; } }
    static void Main(string[] args)
    {
        Application.Run(new Fixture { Text = args[0], StartPosition = FormStartPosition.Manual, Width = 240, Height = 120 });
    }
}
'@
            $script:fixtureName = "win-app-spy-fixture-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
            $script:fixtureExe = Join-Path $TestDrive "$fixtureName.exe"
            $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
            & $csc /nologo /target:winexe /reference:System.Windows.Forms.dll "/out:$fixtureExe" $source | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Cannot compile the fixture app with $csc." }

            # Starts the fixture outside win-app-spy (as the user would) and waits for its window.
            function Start-Fixture {
                param([string] $Title)
                $process = Start-Process $script:fixtureExe -ArgumentList $Title -PassThru
                $clock = [Diagnostics.Stopwatch]::StartNew()
                do {
                    if ($clock.ElapsedMilliseconds -gt 10000) { throw "The fixture '$Title' showed no window." }
                    Start-Sleep -Milliseconds 100
                    $process.Refresh()
                } while ($process.MainWindowHandle -eq 0)
                $process
            }

            function New-Title { "win-app-spy-test-$([guid]::NewGuid().ToString('N'))" }
        }

        AfterEach { Get-Process -Name $script:fixtureName -ErrorAction SilentlyContinue | Stop-Process -Force }

        It 'attaches by <selector> and returns the pid, title and UIA mode' -ForEach @(
            @{ selector = 'pid' }
            @{ selector = 'process' }
            @{ selector = 'title' }
        ) {
            $title = New-Title
            $app = Start-Fixture $title
            $value = @{ pid = $app.Id; process = "$script:fixtureName.exe"; title = $title.Substring(4) }[$selector]

            $result = Invoke-Spy (@{ command = 'attach'; app = @{ $selector = $value } } | ConvertTo-Json)

            $result.ExitCode | Should -Be 0
            $result.Json.data.app.pid | Should -Be $app.Id
            $result.Json.data.app.title | Should -Be $title
            $result.Json.data.app.uia | Should -Be 'UIA3'
        }

        It 'answers APP_AMBIGUOUS with the candidates when several apps match' {
            $first = Start-Fixture (New-Title)
            $second = Start-Fixture (New-Title)

            $result = Invoke-Spy "{ `"command`": `"attach`", `"app`": { `"process`": `"$script:fixtureName`" } }"

            $result.ExitCode | Should -Be 1
            $result.Json.error.code | Should -Be 'APP_AMBIGUOUS'
            $result.Json.error.message | Should -Match "pid $($first.Id)\b"
            $result.Json.error.message | Should -Match "pid $($second.Id)\b"
        }

        It 'targets the attached app, never closes it, and lets an explicit app override it' {
            $launchedTitle = New-Title
            $launch = Invoke-Spy (@{ command = 'launch'; exe = $script:fixtureExe; args = $launchedTitle } | ConvertTo-Json)
            $launch.ExitCode | Should -Be 0
            $attached = Start-Fixture (New-Title)
            (Invoke-Spy "{ `"command`": `"attach`", `"app`": { `"pid`": $($attached.Id) } }").ExitCode | Should -Be 0

            $refused = Invoke-Spy '{ "command": "close", "force": true }'

            $refused.Json.error.code | Should -Be 'NOT_LAUNCHED'
            $refused.Json.error.message | Should -Match "\b$($attached.Id)\b"
            $attached.HasExited | Should -BeFalse

            $closed = Invoke-Spy (@{ command = 'close'; app = @{ title = $launchedTitle } } | ConvertTo-Json)

            $closed.ExitCode | Should -Be 0
            $closed.Json.data.pid | Should -Be $launch.Json.data.app.pid
            $attached.HasExited | Should -BeFalse
        }
    }
}
