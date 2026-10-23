# Covers the screenshot command of spy.csx (screenshot.csx) through its JSON contract, against
# fixture-app.ps1. Skipped in CI, which has no desktop to show it on.
BeforeDiscovery {
    $script:skip = -not (Get-Command dotnet-script -ErrorAction SilentlyContinue) -or [bool] $env:CI
}

BeforeAll {
    . (Join-Path $PSScriptRoot 'spy-test-helpers.ps1')
    Initialize-SpyWorkingFolder
    Add-Type -AssemblyName System.Drawing

    function Get-Screenshot {
        param([string] $XPath)
        $request = @{ command = 'screenshot'; app = @{ pid = $script:fixture.Id } }
        if ($PSBoundParameters.ContainsKey('XPath')) { $request.xpath = $XPath }
        Invoke-Spy $request
    }

    # The image's size and how many distinct colours a sample of its pixels has.
    function Read-Png {
        param([string] $Path)
        $bitmap = [System.Drawing.Bitmap]::new($Path)
        try {
            $colours = [Collections.Generic.HashSet[int]]::new()
            for ($x = 0; $x -lt $bitmap.Width; $x += [Math]::Max(1, [int] ($bitmap.Width / 40))) {
                for ($y = 0; $y -lt $bitmap.Height; $y += [Math]::Max(1, [int] ($bitmap.Height / 40))) {
                    $null = $colours.Add($bitmap.GetPixel($x, $y).ToArgb())
                }
            }
            [pscustomobject] @{ Width = $bitmap.Width; Height = $bitmap.Height; Colours = $colours.Count }
        }
        finally { $bitmap.Dispose() }
    }
}

AfterAll { Restore-SpyConsoleEncoding }

Describe 'screenshot' -Skip:$skip {
    BeforeAll {
        Enter-GuiLock
        $script:fixture = Start-FixtureApp
    }

    AfterAll {
        if ($script:fixture) { Stop-Process -Id $script:fixture.Id -Force -ErrorAction SilentlyContinue }
        Exit-GuiLock
    }

    It 'captures the app''s front window into a PNG in the working folder when no xpath is sent' {
        $result = Get-Screenshot

        $result.ExitCode | Should -Be 0
        $data = $result.Json.data
        $data.Keys | Should -Not -Contain 'element'
        $data.window.title | Should -BeIn @('Fixture', 'Dialog')
        $data.window.handle | Should -BeGreaterThan 0
        Split-Path $data.path -Parent | Should -Be $script:spyWorkingFolder
        $data.path | Should -Match '\.png$'
        $image = Read-Png $data.path
        $image.Width | Should -BeGreaterThan 100
        $image.Height | Should -BeGreaterThan 100
        $image.Colours | Should -BeGreaterThan 1
    }

    It 'captures just the element an xpath matches and echoes the xpath' {
        $xpath = "//Button[@AutomationId='SaveBtn']"
        $bounds = (Invoke-Spy @{ command = 'get-state'; app = @{ pid = $script:fixture.Id }; locators = @($xpath); states = @('bounds') }).Json.data.elements[0].state.bounds

        $result = Get-Screenshot $xpath

        $result.ExitCode | Should -Be 0
        $result.Json.data.element | Should -BeExactly $xpath
        $result.Json.data.window.title | Should -BeExactly 'Fixture'
        $image = Read-Png $result.Json.data.path
        $image.Width | Should -Be $bounds.width
        $image.Height | Should -Be $bounds.height
        $image.Colours | Should -BeGreaterThan 1
    }

    It 'names the window the element is in, here a second top-level window' {
        $result = Get-Screenshot "//Window[@AutomationId='DialogForm']//Button[@Name='OK']"

        $result.ExitCode | Should -Be 0
        $result.Json.data.window.title | Should -BeExactly 'Dialog'
    }

    It 'captures a window the xpath matches whole' {
        $result = Get-Screenshot "/Window[@AutomationId='MainForm']"

        $result.ExitCode | Should -Be 0
        $result.Json.data.window.title | Should -BeExactly 'Fixture'
        $image = Read-Png $result.Json.data.path
        $image.Width | Should -BeGreaterThan 500
        $image.Height | Should -BeGreaterThan 300
    }

    It 'answers <code> as get-state does and writes no file for <xpath>' -ForEach @(
        @{ xpath = "//Button[@AutomationId='NoSuchBtn']"; code = 'ELEMENT_NOT_FOUND' }
        @{ xpath = "//Button[@Name='OK']"; code = 'AMBIGUOUS_MATCH' }
        @{ xpath = "//Buton"; code = 'INVALID_REQUEST' }
    ) {
        $before = @(Get-ChildItem -LiteralPath $script:spyWorkingFolder -Filter *.png).Count

        $result = Get-Screenshot $xpath

        $result.ExitCode | Should -Be 20
        $result.ResultLines | Should -Be 0
        $result.Json.error.code | Should -Be $code
        @(Get-ChildItem -LiteralPath $script:spyWorkingFolder -Filter *.png).Count | Should -Be $before
    }

    It 'lists the count and the candidates'' concrete xpaths on AMBIGUOUS_MATCH' {
        $result = Get-Screenshot "//Button[@Name='OK']"

        $result.Json.error.count | Should -Be 3
        $result.Json.error.candidates.xpath | Should -Contain "/Window[@AutomationId='MainForm']/Pane[@AutomationId='Layout']/Button[@AutomationId='OkA']"
    }

    It 'answers INVALID_REQUEST when xpath is not a string' {
        $result = Invoke-Spy @{ command = 'screenshot'; app = @{ pid = $script:fixture.Id }; xpath = 42 }

        $result.ExitCode | Should -Be 20
        $result.Json.error.code | Should -Be 'INVALID_REQUEST'
    }

    # Minimizes the dialog, so it runs last.
    It 'answers that a minimized window has no image' {
        $dialog = (Get-Screenshot "/Window[@AutomationId='DialogForm']").Json.data.window.handle
        Add-Type -Namespace SpyTests -Name User32 -MemberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr window, int command);'
        $null = [SpyTests.User32]::ShowWindow([IntPtr] $dialog, 6)

        $result = Get-Screenshot "/Window[@AutomationId='DialogForm']"

        $result.ExitCode | Should -Be 20
        $result.Json.error.message | Should -Match 'minimized'
    }
}

Describe 'screenshot without an app' -Skip:(-not (Get-Command dotnet-script -ErrorAction SilentlyContinue)) {
    It 'answers APP_NOT_FOUND when no app is active' {
        $result = Invoke-Spy @{ command = 'screenshot' }

        $result.ExitCode | Should -Be 20
        $result.Json.error.code | Should -Be 'APP_NOT_FOUND'
    }
}
