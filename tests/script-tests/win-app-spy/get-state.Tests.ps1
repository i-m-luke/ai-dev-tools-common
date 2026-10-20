# Covers the get-state command of spy.csx (get-state.csx and the XPath locators of locator.csx)
# through its contract, against fixture-app.ps1. Skipped in CI, which has no desktop to show it on.
BeforeDiscovery {
    $script:skip = -not (Get-Command dotnet-script -ErrorAction SilentlyContinue) -or [bool] $env:CI
}

BeforeAll {
    . (Join-Path $PSScriptRoot 'spy-test-helpers.ps1')
    Initialize-SpyWorkingFolder

    # Sends get-state for the locators to the fixture app; returns the result and its items keyed by xpath.
    function Get-State {
        param([string[]] $Locators, [string[]] $States)
        $request = @{ command = 'get-state'; app = @{ pid = $script:fixture.Id }; locators = @($Locators) }
        if ($PSBoundParameters.ContainsKey('States')) { $request.states = @($States) }
        $result = Invoke-Spy $request
        $items = @{}
        foreach ($item in $result.Json.data.elements) { $items[$item.xpath] = $item }
        $result | Add-Member -NotePropertyName Items -NotePropertyValue $items -PassThru
    }
}

AfterAll { Restore-SpyConsoleEncoding }

Describe 'get-state' -Skip:$skip {
    BeforeAll {
        Enter-GuiLock
        $script:fixture = Start-FixtureApp
    }

    AfterAll {
        if ($script:fixture) { Stop-Process -Id $script:fixture.Id -Force -ErrorAction SilentlyContinue }
        Exit-GuiLock
    }

    It 'returns only the xpath for a locator that matches one element when no states are asked' {
        $result = Get-State "//Button[@AutomationId='SaveBtn']"

        $result.ExitCode | Should -Be 0
        $result.Json.data.elements.Count | Should -Be 1
        $item = $result.Json.data.elements[0]
        $item.xpath | Should -BeExactly "//Button[@AutomationId='SaveBtn']"
        $item.Keys | Should -Be @('xpath')
    }

    It 'returns just the requested states' {
        $result = Get-State "//Button[@AutomationId='SaveBtn']" -States name, automationId, controlType, className

        $result.ExitCode | Should -Be 0
        $state = $result.Items["//Button[@AutomationId='SaveBtn']"].state
        $state.Keys | Sort-Object | Should -Be @('automationId', 'className', 'controlType', 'name')
        $state.name | Should -BeExactly 'Save'
        $state.automationId | Should -BeExactly 'SaveBtn'
        $state.controlType | Should -BeExactly 'Button'
        $state.className | Should -Match '^WindowsForms10\.Button\.'
    }

    It 'reads the <key> state of <xpath>' -ForEach @(
        @{ key = 'enabled'; xpath = "//Button[@AutomationId='SaveBtn']"; expected = $true }
        @{ key = 'enabled'; xpath = "//Button[@AutomationId='CancelBtn']"; expected = $false }
        @{ key = 'offscreen'; xpath = "//Button[@AutomationId='SaveBtn']"; expected = $false }
        @{ key = 'toggle'; xpath = "//CheckBox[@AutomationId='WrapBox']"; expected = 'on' }
        @{ key = 'value'; xpath = "//Edit[@AutomationId='NameBox']"; expected = 'hello' }
    ) {
        $result = Get-State $xpath -States $key

        $result.Items[$xpath].state[$key] | Should -Be $expected
    }

    It 'reads the bounds of an element as its screen rectangle' {
        $result = Get-State "//Window[@AutomationId='MainForm']" -States bounds

        $bounds = $result.Items["//Window[@AutomationId='MainForm']"].state.bounds
        $bounds.Keys | Sort-Object | Should -Be @('height', 'width', 'x', 'y')
        $bounds.width | Should -BeGreaterThan 0
        $bounds.height | Should -BeGreaterThan 0
    }

    It 'leaves out a state the element does not have' {
        $result = Get-State "//Button[@AutomationId='SaveBtn']" -States name, toggle

        $result.Items["//Button[@AutomationId='SaveBtn']"].state.Keys | Should -Be @('name')
    }

    It 'answers ELEMENT_NOT_FOUND for a locator without a match, keeps the other items and exits 0' {
        $result = Get-State "//Button[@AutomationId='NoSuchBtn']", "//Button[@AutomationId='SaveBtn']" -States name

        $result.ExitCode | Should -Be 0
        $result.Json.Keys | Should -Not -Contain 'error'
        $result.Items["//Button[@AutomationId='NoSuchBtn']"].error.code | Should -Be 'ELEMENT_NOT_FOUND'
        $result.Items["//Button[@AutomationId='NoSuchBtn']"].Keys | Should -Not -Contain 'state'
        $result.Items["//Button[@AutomationId='SaveBtn']"].state.name | Should -BeExactly 'Save'
    }

    It 'answers AMBIGUOUS_MATCH with the count and every candidate''s concrete xpath and state' {
        $result = Get-State "//Button[@Name='OK']" -States automationId

        $result.ExitCode | Should -Be 0
        $itemError = $result.Items["//Button[@Name='OK']"].error
        $itemError.code | Should -Be 'AMBIGUOUS_MATCH'
        $itemError.count | Should -Be 3
        $itemError.candidates.state.automationId | Sort-Object | Should -Be @('DialogOk', 'OkA', 'OkB')
        $itemError.candidates.xpath | Should -Contain "/Window[@AutomationId='MainForm']/Pane[@AutomationId='Layout']/Button[@AutomationId='OkA']"
    }

    It 'gives ambiguous candidates xpaths that each match exactly their element' {
        $candidates = (Get-State "//Button[@Name='OK']" -States automationId).Items["//Button[@Name='OK']"].error.candidates

        $result = Get-State $candidates.xpath -States automationId

        $result.ExitCode | Should -Be 0
        foreach ($candidate in $candidates) {
            $result.Items[$candidate.xpath].state.automationId | Should -Be $candidate.state.automationId
        }
    }

    It 'lists at most 5 candidates and counts all matches' {
        $result = Get-State "//Button[@Name='Item']"

        $itemError = $result.Items["//Button[@Name='Item']"].error
        $itemError.count | Should -Be 6
        $itemError.candidates.Count | Should -Be 5
        $itemError.candidates.xpath | Select-Object -Unique | Should -HaveCount 5
    }

    It 'returns every match of an all-locator with its concrete xpath and state, mixed with a string locator' {
        $result = Invoke-Spy @{
            command = 'get-state'; app = @{ pid = $script:fixture.Id }; states = @('automationId')
            locators = @(@{ xpath = "//Button[@Name='Item']"; all = $true }, "//Button[@AutomationId='SaveBtn']")
        }

        $result.ExitCode | Should -Be 0
        $all, $single = $result.Json.data.elements
        $all.matches.Count | Should -Be 6
        $all.matches.state.automationId | Should -Be @('Item1', 'Item2', 'Item3', 'Item4', 'Item5', 'Item6')
        (Get-State $all.matches.xpath -States automationId).ExitCode | Should -Be 0
        $single.state.automationId | Should -BeExactly 'SaveBtn'
    }

    It 'matches <xpath> to <expected>' -ForEach @(
        @{ xpath = "/Window[@AutomationId='MainForm']/Pane[@AutomationId='Layout']/Button[@AutomationId='SaveBtn']"; expected = 'SaveBtn' }
        @{ xpath = "//Pane[@AutomationId='Layout']/Button[3]"; expected = 'OkA' }
        @{ xpath = "//Pane[@AutomationId='Group']/Button[1]"; expected = 'InnerBtn' }
        @{ xpath = "//Pane[@AutomationId='Group']//Button[@Name='Inner']"; expected = 'InnerBtn' }
        @{ xpath = "//Window[@AutomationId='MainForm']//Button[@Name='Inner']"; expected = 'InnerBtn' }
        @{ xpath = "//Button[@Name='Item'][2]"; expected = 'Item2' }
        @{ xpath = "//Window[@AutomationId='DialogForm']//Button[@Name='OK']"; expected = 'DialogOk' }
        @{ xpath = "/Window[@Name='Dialog']/Button[ @AutomationId = `"DialogOk`" ]"; expected = 'DialogOk' }
        @{ xpath = "//Button[@Name='OK' and @AutomationId='OkB']"; expected = 'OkB' }
        @{ xpath = "//Button[@AutomationId='NoSuchBtn' or @Name='Inner']"; expected = 'InnerBtn' }
        @{ xpath = "//Button[@AutomationId='InnerBtn' or @AutomationId='SaveBtn' and @Name='NoSuch']"; expected = 'InnerBtn' }
        @{ xpath = "//Button[contains(@AutomationId, 'nnerB')]"; expected = 'InnerBtn' }
        @{ xpath = "//Button[contains( @Name ,`"Sav`" ) and contains(@ClassName, 'Button')]"; expected = 'SaveBtn' }
        @{ xpath = "//Button[contains(@AutomationId, 'Item')][3]"; expected = 'Item3' }
        @{ xpath = "//Button[(@AutomationId='InnerBtn' or @AutomationId='SaveBtn') and @Name='Save']"; expected = 'SaveBtn' }
    ) {
        $result = Get-State $xpath -States automationId

        $result.ExitCode | Should -Be 0
        $result.Items[$xpath].state.automationId | Should -BeExactly $expected
    }

    It 'finds nothing for <xpath>' -ForEach @(
        @{ xpath = "/Window[@AutomationId='MainForm']/Button[@AutomationId='InnerBtn']" }
        @{ xpath = "/Button[@AutomationId='SaveBtn']" }
        @{ xpath = "//Pane[@AutomationId='Layout']/Button[9]" }
        @{ xpath = "//Button[@Name='save']" }
    ) {
        (Get-State $xpath).Items[$xpath].error.code | Should -Be 'ELEMENT_NOT_FOUND'
    }

    It 'answers <xpath>, outside the supported subset, with INVALID_REQUEST on its item' -ForEach @(
        @{ xpath = "Button" }
        @{ xpath = "//Buton" }
        @{ xpath = "//button" }
        @{ xpath = "//Button[@HelpText='x']" }
        @{ xpath = "//Button[0]" }
        @{ xpath = "//Button[@Name='x'" }
        @{ xpath = "//Button[@Name=x]" }
    ) {
        $result = Get-State $xpath, "//Button[@AutomationId='SaveBtn']"

        $result.ExitCode | Should -Be 0
        $result.Items[$xpath].error.code | Should -Be 'INVALID_REQUEST'
        $result.Items[$xpath].error.message | Should -Not -BeNullOrEmpty
        $result.Items["//Button[@AutomationId='SaveBtn']"].Keys | Should -Not -Contain 'error'
    }

    It 'answers <case> with INVALID_REQUEST for the whole request' -ForEach @(
        @{ case = 'an unknown state key'; request = @{ command = 'get-state'; locators = @('//Window'); states = @('colour') } }
        @{ case = 'missing locators'; request = @{ command = 'get-state' } }
        @{ case = 'an empty locator list'; request = @{ command = 'get-state'; locators = @() } }
        @{ case = 'a locator that is not a string'; request = @{ command = 'get-state'; locators = @(42) } }
        @{ case = 'a locator object with a non-boolean all'; request = @{ command = 'get-state'; locators = @(@{ xpath = '//Window'; all = 'yes' }) } }
    ) {
        $request.app = @{ pid = $script:fixture.Id }

        $result = Invoke-Spy $request

        $result.ExitCode | Should -Be 2
        $result.ResultLines | Should -Be 0
        $result.Json.error.code | Should -Be 'INVALID_REQUEST'
    }
}

Describe 'get-state without an app' -Skip:(-not (Get-Command dotnet-script -ErrorAction SilentlyContinue)) {
    It 'answers APP_NOT_FOUND when the app''s process is not running' {
        $gone = Start-Process (Join-Path $PSHOME 'pwsh.exe') -ArgumentList '-NoProfile', '-Command', 'exit' -WindowStyle Hidden -PassThru
        $gone.WaitForExit()

        $result = Invoke-Spy @{ command = 'get-state'; app = @{ pid = $gone.Id }; locators = @('//Window') }

        $result.ExitCode | Should -Be 2
        $result.Json.error.code | Should -Be 'APP_NOT_FOUND'
    }
}
