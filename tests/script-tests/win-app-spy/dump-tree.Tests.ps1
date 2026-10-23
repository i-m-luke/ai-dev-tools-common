# Covers the dump-tree command of spy.csx (dump-tree.csx) through its JSON contract, against
# fixture-app.ps1. Skipped in CI, which has no desktop to show it on.
BeforeDiscovery {
    $script:skip = -not (Get-Command dotnet-script -ErrorAction SilentlyContinue) -or [bool] $env:CI
}

BeforeAll {
    . (Join-Path $PSScriptRoot 'spy-test-helpers.ps1')
    Initialize-SpyWorkingFolder

    # Sends dump-tree with the given fields to the fixture app.
    function Get-Dump {
        param([hashtable] $Fields = @{})
        $request = @{ command = 'dump-tree'; app = @{ pid = $script:fixture.Id } } + $Fields
        Invoke-Spy $request
    }

    # Every node of a dump, depth-first.
    function Get-DumpNode {
        param($Nodes)
        foreach ($node in $Nodes) {
            $node
            if ($node.children) { Get-DumpNode $node.children }
        }
    }

    function Find-DumpNode {
        param($Nodes, [string] $XPath)
        Get-DumpNode $Nodes | Where-Object { $_.xpath -ceq $XPath }
    }
}

AfterAll { Restore-SpyConsoleEncoding }

Describe 'dump-tree' -Skip:$skip {
    BeforeAll {
        Enter-GuiLock
        $script:fixture = Start-FixtureApp
    }

    AfterAll {
        if ($script:fixture) { Stop-Process -Id $script:fixture.Id -Force -ErrorAction SilentlyContinue }
        Exit-GuiLock
    }

    It 'lists the app''s windows with their elements nested, each with its xpath' {
        $result = Get-Dump

        $result.ExitCode | Should -Be 0 -Because $result.Raw
        $result.Json.data.truncated | Should -BeFalse
        $result.Json.data.nodes.xpath | Should -Contain "/Window[@AutomationId='MainForm']"
        $result.Json.data.nodes.xpath | Should -Contain "/Window[@AutomationId='DialogForm']"
        $layout = Find-DumpNode $result.Json.data.nodes "/Window[@AutomationId='MainForm']/Pane[@AutomationId='Layout']"
        $layout.children.xpath | Should -Contain "/Window[@AutomationId='MainForm']/Pane[@AutomationId='Layout']/Button[@AutomationId='SaveBtn']"
        $group = Find-DumpNode $result.Json.data.nodes "/Window[@AutomationId='MainForm']/Pane[@AutomationId='Layout']/Pane[@AutomationId='Group']"
        $group.children.Count | Should -Be 7
        $group.children[0].Keys | Should -Be @('xpath')
    }

    It 'gives every node the requested states' {
        $result = Get-Dump @{ states = @('name', 'automationId') }

        $result.ExitCode | Should -Be 0 -Because $result.Raw
        $save = Find-DumpNode $result.Json.data.nodes "/Window[@AutomationId='MainForm']/Pane[@AutomationId='Layout']/Button[@AutomationId='SaveBtn']"
        $save.state.name | Should -BeExactly 'Save'
        $save.state.automationId | Should -BeExactly 'SaveBtn'
        (Get-DumpNode $result.Json.data.nodes | Where-Object { -not $_.state }) | Should -BeNullOrEmpty
    }

    It 'gives every node an xpath that get-state resolves back to that node''s element' {
        $states = @('controlType', 'name', 'automationId', 'bounds')
        $nodes = @(Get-DumpNode (Get-Dump @{ states = $states }).Json.data.nodes)

        $result = Invoke-Spy @{ command = 'get-state'; app = @{ pid = $script:fixture.Id }; locators = @($nodes.xpath); states = $states }

        $result.ExitCode | Should -Be 0 -Because $result.Raw
        $nodes.Count | Should -BeGreaterThan 20
        foreach ($node in $nodes) {
            $item = $result.Json.data.elements | Where-Object { $_.xpath -ceq $node.xpath }
            ($item.state | ConvertTo-Json -Compress) | Should -BeExactly ($node.state | ConvertTo-Json -Compress) -Because $node.xpath
        }
    }

    It 'starts at the element the root xpath matches, giving it its concrete xpath' {
        $result = Get-Dump @{ root = "//Pane[@AutomationId='Group']"; states = @('automationId') }

        $result.ExitCode | Should -Be 0 -Because $result.Raw
        $result.Json.data.nodes.Count | Should -Be 1
        $root = $result.Json.data.nodes[0]
        $root.xpath | Should -BeExactly "/Window[@AutomationId='MainForm']/Pane[@AutomationId='Layout']/Pane[@AutomationId='Group']"
        $root.state.automationId | Should -BeExactly 'Group'
        $root.children.state.automationId | Should -Be @('InnerBtn', 'Item1', 'Item2', 'Item3', 'Item4', 'Item5', 'Item6')
    }

    It 'answers <code> for <case> as root' -ForEach @(
        @{ case = 'an xpath without a match'; root = "//Pane[@AutomationId='Nothing']"; code = 'ELEMENT_NOT_FOUND' }
        @{ case = 'an xpath with several matches'; root = "//Button[@Name='OK']"; code = 'AMBIGUOUS_MATCH' }
        @{ case = 'an unsupported xpath'; root = "//Pane[@HelpText='x']"; code = 'INVALID_REQUEST' }
    ) {
        $result = Get-Dump @{ root = $root }

        $result.ExitCode | Should -Be 20
        $result.Json.error.code | Should -Be $code
        $result.ResultLines | Should -Be 0
    }

    It 'lists <depth> level(s) below the app and gives the cut nodes their childCount' -ForEach @(
        @{ depth = 1; cut = @{ "/Window[@AutomationId='MainForm']" = 2; "/Window[@AutomationId='DialogForm']" = 2 } }
        @{ depth = 2; cut = @{ "/Window[@AutomationId='MainForm']/Pane[@AutomationId='Layout']" = 7; "/Window[@AutomationId='MainForm']/TitleBar[@AutomationId='TitleBar']" = 4; "/Window[@AutomationId='DialogForm']/TitleBar[@AutomationId='TitleBar']" = 4 } }
    ) {
        $result = Get-Dump @{ depth = $depth }

        $result.ExitCode | Should -Be 0 -Because $result.Raw
        $result.Json.data.truncated | Should -BeTrue
        $nodes = @(Get-DumpNode $result.Json.data.nodes)
        $nodes | ForEach-Object { ($_.xpath -split '/').Count - 1 } | Sort-Object -Unique | Select-Object -Last 1 | Should -Be $depth
        foreach ($node in $nodes) {
            $node.childCount | Should -Be $cut[$node.xpath] -Because $node.xpath
            if ($cut.ContainsKey($node.xpath)) { $node.Keys | Should -Not -Contain 'children' }
        }
    }

    It 'counts depth from the root element' {
        $result = Get-Dump @{ root = "//Pane[@AutomationId='Layout']"; depth = 1 }

        $result.Json.data.truncated | Should -BeTrue
        $layout = $result.Json.data.nodes[0]
        $layout.children.Count | Should -Be 7
        $layout.Keys | Should -Not -Contain 'childCount'
        $group = $layout.children | Where-Object { $_.xpath.EndsWith("/Pane[@AutomationId='Group']") }
        $group.childCount | Should -Be 7
        $group.Keys | Should -Not -Contain 'children'
    }

    It 'stops at maxNodes, listing upper levels first, and gives partly listed nodes their childCount' {
        $result = Get-Dump @{ maxNodes = 3 }

        $result.ExitCode | Should -Be 0 -Because $result.Raw
        $result.Json.data.truncated | Should -BeTrue
        @(Get-DumpNode $result.Json.data.nodes).Count | Should -Be 3
        # Windows come in z-order: the first one gets the one node left, the second none.
        $first, $second = $result.Json.data.nodes
        $first.childCount | Should -Be 2
        $first.children.Count | Should -Be 1
        $first.children[0].childCount | Should -Be ($first.xpath -ceq "/Window[@AutomationId='MainForm']" ? 7 : $null)
        $second.childCount | Should -Be 2
        $second.Keys | Should -Not -Contain 'children'
    }

    It 'gives data the window count when maxNodes leaves out windows' {
        $result = Get-Dump @{ maxNodes = 1 }

        $result.Json.data.truncated | Should -BeTrue
        $result.Json.data.childCount | Should -Be 2
        $result.Json.data.nodes.Count | Should -Be 1
    }

    It 'answers INVALID_REQUEST for <case>' -ForEach @(
        @{ case = 'depth 0'; fields = @{ depth = 0 } }
        @{ case = 'a depth that is not a number'; fields = @{ depth = 'deep' } }
        @{ case = 'maxNodes 0'; fields = @{ maxNodes = 0 } }
        @{ case = 'includeOffscreen that is not a bool'; fields = @{ includeOffscreen = 'yes' } }
        @{ case = 'an unknown state key'; fields = @{ states = @('colour') } }
        @{ case = 'a root that is not a string'; fields = @{ root = 42 } }
    ) {
        $result = Get-Dump $fields

        $result.ExitCode | Should -Be 20
        $result.Json.error.code | Should -Be 'INVALID_REQUEST'
    }
}
