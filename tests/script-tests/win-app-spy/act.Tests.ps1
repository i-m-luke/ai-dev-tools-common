# Covers the act command of win-app-spy.csx (act.csx) through its JSON contract, against the Act window
# of fixture-app.ps1. Actions move the real mouse and keyboard, so the tests hold the GUI lock; skipped
# in CI, which has no desktop.
BeforeDiscovery {
    $script:skip = -not (Get-Command dotnet-script -ErrorAction SilentlyContinue) -or [bool] $env:CI
}

BeforeAll {
    . (Join-Path $PSScriptRoot 'spy-test-helpers.ps1')
    Initialize-SpyWorkingFolder

    function Invoke-Act {
        param([string] $Locator, [string] $Action, [hashtable] $Extra = @{})
        $request = @{ command = 'act'; app = @{ pid = $script:fixture.Id }; locator = $Locator; action = $Action } + $Extra
        Invoke-Spy $request
    }

    function Get-StateOf {
        param([string] $Locator, [string] $Key)
        $result = Invoke-Spy @{ command = 'get-state'; app = @{ pid = $script:fixture.Id }; locators = @($Locator); states = @($Key) }
        $result.Json.data.elements[0].state[$Key]
    }

    function Get-ActLog { Get-StateOf "//Edit[@AutomationId='ActLog']" value }
}

AfterAll { Restore-SpyConsoleEncoding }

Describe 'act' -Skip:$skip {
    BeforeAll {
        Enter-GuiLock
        $script:fixture = Start-FixtureApp -WithActForm
    }

    AfterAll {
        if ($script:fixture) { Stop-Process -Id $script:fixture.Id -Force -ErrorAction SilentlyContinue }
        Exit-GuiLock
    }

    It 'invokes a button' {
        $result = Invoke-Act "//Button[@AutomationId='InvokeBtn']" invoke

        $result.ExitCode | Should -Be 0 -Because $result.Raw
        Get-ActLog | Should -Match '\binvoked$'
    }

    It 'toggles a check box and returns its state after the action' {
        $result = Invoke-Act "//CheckBox[@AutomationId='FlagA']" toggle @{ states = @('toggle') }

        $result.ExitCode | Should -Be 0 -Because $result.Raw
        $result.Json.data.state.toggle | Should -Be 'on'
    }

    It 'sets the value of an edit box' {
        $result = Invoke-Act "//Edit[@AutomationId='TypeBox']" setValue @{ value = 'set'; states = @('value') }

        $result.Json.data.state.value | Should -BeExactly 'set'
    }

    It 'answers AMBIGUOUS_MATCH and toggles nothing when the locator matches several elements' {
        $before = Get-StateOf "//CheckBox[@AutomationId='FlagB']" toggle

        $result = Invoke-Act "//CheckBox[@Name='Flag']" toggle

        $result.ExitCode | Should -Be 1
        $result.Json.error.code | Should -Be 'AMBIGUOUS_MATCH'
        Get-StateOf "//CheckBox[@AutomationId='FlagB']" toggle | Should -Be $before
    }

    It 'answers ACTION_FAILED when the element lacks the action''s pattern' {
        $result = Invoke-Act "//CheckBox[@AutomationId='FlagB']" expand

        $result.Json.error.code | Should -Be 'ACTION_FAILED'
    }

    It 'answers INVALID_REQUEST for an unknown action or key' -ForEach @(
        @{ action = 'smash'; extra = @{} }
        @{ action = 'key'; extra = @{ keys = 'Ctrl+Nope' } }
    ) {
        (Invoke-Act "//Button[@AutomationId='InvokeBtn']" $action $extra).Json.error.code | Should -Be 'INVALID_REQUEST'
    }
}
