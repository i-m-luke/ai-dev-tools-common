# Covers spy.csx through its contract — arguments, help, result line, stderr and exit codes —
# together with the files it loads: core.csx, locator.csx, close.csx and launch.csx, and the
# NuGet.Config beside it. Runs that need a GUI app (Notepad) are verified by hand, since parallel
# runs share one desktop.
BeforeDiscovery {
    $script:noDotnetScript = -not (Get-Command dotnet-script -ErrorAction SilentlyContinue)
}

BeforeAll {
    . (Join-Path $PSScriptRoot 'spy-test-helpers.ps1')
    Initialize-SpyWorkingFolder
}

AfterAll { Restore-SpyConsoleEncoding }

Describe 'NuGet.Config' {
    It 'restores from nuget.org alone, whatever the folders above the skill configure' {
        [xml] $config = Get-Content -LiteralPath (Join-Path (Split-Path $script:spyScript) 'NuGet.Config') -Raw

        $config.configuration.packageSources.ChildNodes.Name | Should -Be @('clear', 'add')
        $config.configuration.packageSources.add.value | Should -Be 'https://api.nuget.org/v3/index.json'
    }
}

Describe 'spy.csx' -Skip:$noDotnetScript {
    It 'prints its help with the error codes and every command, and no result' {
        $result = Invoke-SpyScript -Arguments '--help'

        $result.ExitCode | Should -Be 0
        $result.ResultLines | Should -Be 0
        $text = $result.Stdout -join "`n"
        foreach ($part in 'Exit codes', 'Stderr', 'INVALID_REQUEST', 'UNEXPECTED', 'act', 'attach', 'close', 'dump-tree', 'get-state', 'launch', 'screenshot', 'wait') {
            $text | Should -BeLike "*$part*"
        }
    }

    It 'prints the help of a command' {
        $result = Invoke-SpyScript -Arguments '--help', 'wait'

        $result.ExitCode | Should -Be 0
        $result.Stdout[0] | Should -BeLike 'wait — *'
        ($result.Stdout -join "`n") | Should -BeLike '*condition*'
    }

    It 'answers the help of an unknown command with UNKNOWN_COMMAND and exit 2' {
        $result = Invoke-SpyScript -Arguments '--help', 'fly'

        $result.ExitCode | Should -Be 2
        $result.Json.error.code | Should -Be 'UNKNOWN_COMMAND'
    }

    It 'creates a new working folder under %TEMP%\win-app-spy and returns its path' {
        $first = Invoke-SpyScript -Arguments '--new-working-folder'
        $second = Invoke-SpyScript -Arguments '--new-working-folder'
        try {
            $first.ExitCode | Should -Be 0
            $first.ResultLines | Should -Be 1
            $first.Json.workingFolder | Should -Exist
            Split-Path $first.Json.workingFolder -Parent | Should -Be (Join-Path ([IO.Path]::GetTempPath().TrimEnd('\')) 'win-app-spy')
            Split-Path $first.Json.workingFolder -Leaf | Should -Match '^\d{8}-\d{6}(-\d+)?$'
            $second.Json.workingFolder | Should -Not -Be $first.Json.workingFolder
        }
        finally {
            foreach ($folder in $first.Json.workingFolder, $second.Json.workingFolder) {
                if ($folder) { Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue }
            }
        }
    }

    It 'answers an unknown command with an error on stderr, no result and exit 2' {
        $result = Invoke-Spy '{ "command": "fly" }'

        $result.ExitCode | Should -Be 2
        $result.ResultLines | Should -Be 0
        $result.Json.error.code | Should -Be 'UNKNOWN_COMMAND'
        $result.Json.error.message | Should -Not -BeNullOrEmpty
    }

    It 'answers arguments other than its own with INVALID_REQUEST and exit 2' {
        $result = Invoke-SpyScript -Arguments 'req.json'

        $result.ExitCode | Should -Be 2
        $result.Json.error.code | Should -Be 'INVALID_REQUEST'
    }

    It 'answers <case> with INVALID_REQUEST and exit 2' -ForEach @(
        @{ case = 'a request that is not JSON'; request = '{ "command": ' }
        @{ case = 'a request that is not an object'; request = '[ "launch" ]' }
        @{ case = 'a request without a command'; request = '{ "exe": "notepad.exe" }' }
        @{ case = 'a field of the wrong type'; request = '{ "command": "launch", "exe": 42 }' }
    ) {
        $result = Invoke-Spy $request

        $result.ExitCode | Should -Be 2
        $result.Json.error.code | Should -Be 'INVALID_REQUEST'
        $result.Json.error.message | Should -Not -BeNullOrEmpty
    }

    It 'answers a missing request file with INVALID_REQUEST and exit 2' {
        $result = Invoke-SpyScript -Arguments '--request-path', (Join-Path $script:spyWorkingFolder 'missing.json')

        $result.ExitCode | Should -Be 2
        $result.Json.error.code | Should -Be 'INVALID_REQUEST'
    }

    Context 'launch' {
        It 'answers an exe that does not exist with APP_NOT_FOUND' {
            $result = Invoke-Spy '{ "command": "launch", "exe": "win-app-spy-no-such-app.exe" }'

            $result.ExitCode | Should -Be 2
            $result.Json.error.code | Should -Be 'APP_NOT_FOUND'
        }

        It 'answers an unknown UIA mode with INVALID_REQUEST' {
            $result = Invoke-Spy '{ "command": "launch", "exe": "notepad.exe", "uia": "UIA4" }'

            $result.ExitCode | Should -Be 2
            $result.Json.error.code | Should -Be 'INVALID_REQUEST'
        }

        It 'answers TIMEOUT and stops the app when no window appears within the timeout' {
            $marker = "win-app-spy-test-$([guid]::NewGuid())"
            $request = @{
                command = 'launch'
                exe     = Join-Path $PSHOME 'pwsh.exe'
                args    = "-NoProfile -Command `"Start-Sleep 30 # $marker`""
                timeout = 2000
            } | ConvertTo-Json

            $result = Invoke-Spy $request

            $result.ExitCode | Should -Be 2
            $result.Json.error.code | Should -Be 'TIMEOUT'
            Get-CimInstance Win32_Process -Filter "Name = 'pwsh.exe'" |
                Where-Object CommandLine -Like "*$marker*" | Should -BeNullOrEmpty
        }
    }

    Context 'close' {
        BeforeEach { Remove-Item -LiteralPath (Join-Path $script:spyWorkingFolder 'session.json') -ErrorAction SilentlyContinue }

        It 'answers APP_NOT_FOUND when neither app nor an active app is given' {
            $result = Invoke-Spy '{ "command": "close" }'

            $result.ExitCode | Should -Be 2
            $result.Json.error.code | Should -Be 'APP_NOT_FOUND'
        }

        It 'refuses a running app this session did not launch and leaves it running' {
            $other = Start-Process (Join-Path $PSHOME 'pwsh.exe') -ArgumentList '-NoProfile', '-Command', 'Start-Sleep 60' -WindowStyle Hidden -PassThru
            try {
                $result = Invoke-Spy "{ `"command`": `"close`", `"app`": { `"pid`": $($other.Id) }, `"force`": true }"

                $result.ExitCode | Should -Be 2
                $result.Json.error.code | Should -Be 'NOT_LAUNCHED'
                $other.HasExited | Should -BeFalse
            }
            finally { $other | Stop-Process -Force -ErrorAction SilentlyContinue }
        }
    }
}
