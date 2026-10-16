# Covers win-app-spy.csx through its JSON contract, together with the files it loads: core.csx,
# locator.csx, close.csx and launch.csx. Runs that need a GUI app (Notepad) are verified by hand,
# since parallel runs share one desktop.
BeforeDiscovery {
    $script:noDotnetScript = -not (Get-Command dotnet-script -ErrorAction SilentlyContinue)
}

BeforeAll {
    . (Join-Path $PSScriptRoot 'spy-test-helpers.ps1')
    Initialize-SpyWorkingFolder
    $script:mainScript = Join-Path $script:spyWorkingFolder 'win-app-spy.csx'
}

AfterAll { Restore-SpyConsoleEncoding }

Describe 'win-app-spy.csx' -Skip:$noDotnetScript {
    It 'answers an unknown command with an error envelope and exit 1' {
        $result = Invoke-Spy '{ "command": "fly" }'

        $result.ExitCode | Should -Be 1
        $result.Json.command | Should -Be 'fly'
        $result.Json.error.code | Should -Be 'UNKNOWN_COMMAND'
        $result.Json.error.message | Should -Not -BeNullOrEmpty
        $result.Json.Keys | Should -Not -Contain 'data'
        $result.Json.Keys | Should -Not -Contain 'ok'
    }

    It 'answers <case> with INVALID_REQUEST and exit 1' -ForEach @(
        @{ case = 'a request that is not JSON'; request = '{ "command": ' }
        @{ case = 'a request that is not an object'; request = '[ "launch" ]' }
        @{ case = 'a request without a command'; request = '{ "exe": "notepad.exe" }' }
        @{ case = 'a field of the wrong type'; request = '{ "command": "launch", "exe": 42 }' }
    ) {
        $result = Invoke-Spy $request

        $result.ExitCode | Should -Be 1
        $result.Json.error.code | Should -Be 'INVALID_REQUEST'
        $result.Json.error.message | Should -Not -BeNullOrEmpty
    }

    It 'answers a missing request file with INVALID_REQUEST and exit 1' {
        Push-Location $script:spyWorkingFolder
        try { $stdout = & dotnet script $script:mainScript -- missing.json 2>$null | Out-String }
        finally { Pop-Location }

        $LASTEXITCODE | Should -Be 1
        ($stdout | ConvertFrom-Json).error.code | Should -Be 'INVALID_REQUEST'
    }

    Context 'launch' {
        It 'answers an exe that does not exist with APP_NOT_FOUND' {
            $result = Invoke-Spy '{ "command": "launch", "exe": "win-app-spy-no-such-app.exe" }'

            $result.ExitCode | Should -Be 1
            $result.Json.error.code | Should -Be 'APP_NOT_FOUND'
        }

        It 'answers an unknown UIA mode with INVALID_REQUEST' {
            $result = Invoke-Spy '{ "command": "launch", "exe": "notepad.exe", "uia": "UIA4" }'

            $result.ExitCode | Should -Be 1
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

            $result.ExitCode | Should -Be 1
            $result.Json.error.code | Should -Be 'TIMEOUT'
            Get-CimInstance Win32_Process -Filter "Name = 'pwsh.exe'" |
                Where-Object CommandLine -Like "*$marker*" | Should -BeNullOrEmpty
        }
    }

    Context 'close' {
        BeforeEach { Remove-Item -LiteralPath (Join-Path $script:spyWorkingFolder 'session.json') -ErrorAction SilentlyContinue }

        It 'answers APP_NOT_FOUND when neither app nor an active app is given' {
            $result = Invoke-Spy '{ "command": "close" }'

            $result.ExitCode | Should -Be 1
            $result.Json.error.code | Should -Be 'APP_NOT_FOUND'
        }

        It 'refuses a running app this session did not launch and leaves it running' {
            $other = Start-Process (Join-Path $PSHOME 'pwsh.exe') -ArgumentList '-NoProfile', '-Command', 'Start-Sleep 60' -WindowStyle Hidden -PassThru
            try {
                $result = Invoke-Spy "{ `"command`": `"close`", `"app`": { `"pid`": $($other.Id) }, `"force`": true }"

                $result.ExitCode | Should -Be 1
                $result.Json.error.code | Should -Be 'NOT_LAUNCHED'
                $other.HasExited | Should -BeFalse
            }
            finally { $other | Stop-Process -Force -ErrorAction SilentlyContinue }
        }
    }
}
