# Covers the wait command of win-app-spy.csx (wait.csx and the polling of core.csx) through its JSON
# contract, against the Waiter window of fixture-app.ps1 (fixture-waiter.ps1), whose elements change
# on request. GUI runs are skipped in CI, which has no desktop to show the fixture on.
BeforeDiscovery {
    $script:noDotnetScript = -not (Get-Command dotnet-script -ErrorAction SilentlyContinue)
    $script:skipGui = $script:noDotnetScript -or [bool] $env:CI
}

BeforeAll {
    . (Join-Path $PSScriptRoot 'spy-test-helpers.ps1')
    Initialize-SpyWorkingFolder

    # Sends wait for the locator to the fixture app; -Fields adds request fields (condition, timeout, poll).
    function Wait-Element {
        param([string] $Locator, [hashtable] $Fields = @{})
        $request = @{ command = 'wait'; app = @{ pid = $script:fixture.Id }; locator = $Locator } + $Fields
        Invoke-Spy $request
    }

    # Asks the Waiter window to make the change after the delay; the write is atomic, so the fixture
    # never reads half a file.
    function Request-Change {
        param([string] $Change, [int] $DelayMs)
        $file = Join-Path $script:triggers "$Change.trigger"
        Set-Content -LiteralPath "$file.tmp" -Value $DelayMs
        Move-Item -LiteralPath "$file.tmp" -Destination $file
    }
}

AfterAll { Restore-SpyConsoleEncoding }

Describe 'wait' {
    Context 'request' -Skip:$noDotnetScript {
        It 'answers <case> with INVALID_REQUEST' -ForEach @(
            @{ case = 'a missing locator'; request = '{ "command": "wait" }' }
            @{ case = 'an unknown condition'; request = '{ "command": "wait", "locator": "//Button", "condition": "focused" }' }
            @{ case = 'a negative timeout'; request = '{ "command": "wait", "locator": "//Button", "timeout": -1 }' }
            @{ case = 'a poll of 0'; request = '{ "command": "wait", "locator": "//Button", "poll": 0 }' }
            @{ case = 'an xpath outside the subset'; request = '{ "command": "wait", "locator": "//button" }' }
        ) {
            $result = Invoke-Spy $request

            $result.ExitCode | Should -Be 1
            $result.Json.command | Should -Be 'wait'
            $result.Json.error.code | Should -Be 'INVALID_REQUEST'
        }

        It 'answers launch with a poll of 0 with INVALID_REQUEST, as it polls the same way' {
            $result = Invoke-Spy '{ "command": "launch", "exe": "notepad.exe", "poll": 0 }'

            $result.ExitCode | Should -Be 1
            $result.Json.error.code | Should -Be 'INVALID_REQUEST'
        }
    }

    Context 'against the fixture app' -Skip:$skipGui {
        BeforeAll {
            Enter-GuiLock
            $script:triggers = Join-Path $TestDrive 'triggers'
            New-Item -ItemType Directory -Path $script:triggers | Out-Null
            $script:fixture = Start-FixtureApp -TriggerFolder $script:triggers
        }

        AfterAll {
            if ($script:fixture) { Stop-Process -Id $script:fixture.Id -Force -ErrorAction SilentlyContinue }
            Exit-GuiLock
        }

        # The delay outlasts the script's start, so the condition turns true while wait polls.
        It 'returns once <xpath> becomes <condition>' -ForEach @(
            @{ condition = 'exists'; change = 'add'; xpath = "//Button[@AutomationId='AddedLater']" }
            @{ condition = 'gone'; change = 'remove'; xpath = "//Button[@AutomationId='RemoveLater']" }
            @{ condition = 'enabled'; change = 'enable'; xpath = "//Button[@AutomationId='EnableLater']" }
        ) {
            Request-Change $change -DelayMs 3000

            $result = Wait-Element $xpath @{ condition = $condition; timeout = 20000 }

            $result.ExitCode | Should -Be 0 -Because $result.Raw
            $result.Json.data.xpath | Should -BeExactly $xpath
            $result.Json.data.condition | Should -Be $condition
        }

        It 'answers TIMEOUT when <xpath> does not become <condition> in time' -ForEach @(
            @{ condition = 'exists'; xpath = "//Button[@AutomationId='NoSuchButton']" }
            @{ condition = 'gone'; xpath = "//Button[@AutomationId='SaveBtn']" }
            @{ condition = 'enabled'; xpath = "//Button[@AutomationId='CancelBtn']" }
        ) {
            $result = Wait-Element $xpath @{ condition = $condition; timeout = 1000 }

            $result.ExitCode | Should -Be 1
            $result.Json.error.code | Should -Be 'TIMEOUT'
            $result.Json.error.message | Should -Match '1000 ms'
        }

        It 'waits for exists, 10000 ms, polling every 250 ms when the request leaves them out' {
            $clock = [Diagnostics.Stopwatch]::StartNew()
            $result = Wait-Element "//Button[@AutomationId='NoSuchButton']"
            $clock.Stop()

            $result.Json.error.code | Should -Be 'TIMEOUT'
            $result.Json.error.message | Should -Match 'exist'
            $result.Json.error.message | Should -Match '10000 ms'
            $result.Json.error.message | Should -Match 'every 250 ms'
            $clock.Elapsed.TotalSeconds | Should -BeGreaterOrEqual 10
        }

        It 'returns at once when the condition already holds' {
            $result = Wait-Element "//Button[@AutomationId='SaveBtn']"

            $result.ExitCode | Should -Be 0
            $result.Json.data.condition | Should -Be 'exists'
        }

        It 'answers a locator that matches several elements with AMBIGUOUS_MATCH at once' {
            $result = Wait-Element "//Button[@Name='OK']" @{ timeout = 60000 }

            $result.ExitCode | Should -Be 1
            $result.Json.error.code | Should -Be 'AMBIGUOUS_MATCH'
            $result.Json.error.count | Should -Be 3
        }
    }
}
