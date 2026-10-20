BeforeAll {
    . (Join-Path $PSScriptRoot 'gh-test-helpers.ps1')
    $script:labels = 'repos/owner/name/issues/7/labels'
}

Describe 'set-labels.ps1' {
    It 'adds and removes the labels and returns the labels the item carries afterwards (<_>)' -ForEach 'pwsh', 'powershell' {
        Set-GhStub @(
            @{ match = Get-ApiMatch POST $script:labels; stdout = @() }
            @{ match = Get-ApiMatch DELETE "$script:labels/needs-triage"; stdout = @() }
            @{ match = Get-ApiMatch DELETE "$script:labels/needs%20info"; stdout = @() }
            @{ match = Get-ApiMatch GET $script:labels; stdout = @(@{ name = 'bug' }, @{ name = 'ready-for-agent' }) }
        )

        $run = Invoke-SkillScript 'set-labels' @{ Repository = $script:repo; Number = 7; Add = 'bug,ready-for-agent'; Remove = 'needs-triage, needs info' } -Shell $_

        $run.ExitCode | Should -Be 0 -Because $run.Stderr
        $run.Result.labels | Should -Be @('bug', 'ready-for-agent')
        (Get-GhBody (Get-ApiMatch POST $script:labels)).labels | Should -Be @('bug', 'ready-for-agent')
        @(Get-GhCalls | Where-Object { $_.args -contains 'DELETE' }).Count | Should -Be 2
    }

    It 'treats removing a label the item does not carry as done' {
        Set-GhStub @(
            $script:notFound + @{ match = Get-ApiMatch DELETE "$script:labels/wontfix" }
            @{ match = Get-ApiMatch GET $script:labels; stdout = @() }
        )

        $run = Invoke-SkillScript 'set-labels' @{ Repository = $script:repo; Number = 7; Remove = 'wontfix' }

        $run.ExitCode | Should -Be 0 -Because $run.Stderr
        , $run.Result.labels | Should -BeOfType [array]
        $run.Result.labels.Count | Should -Be 0
        @(Get-GhCalls | Where-Object { $_.args -contains 'POST' }).Count | Should -Be 0
    }

    It 'exits 2 when GitHub rejects the labels' {
        Set-GhStub @(@{ match = Get-ApiMatch POST $script:labels; stderr = 'gh: Forbidden (HTTP 403)'; exit = 1 })

        $run = Invoke-SkillScript 'set-labels' @{ Repository = $script:repo; Number = 7; Add = 'bug' }

        $run.ExitCode | Should -Be 2
        $run.Stderr | Should -BeLike '*HTTP 403*'
    }
}
