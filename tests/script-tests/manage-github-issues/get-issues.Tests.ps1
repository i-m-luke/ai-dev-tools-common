BeforeAll {
    . (Join-Path $PSScriptRoot 'gh-test-helpers.ps1')
    $script:issues = @(
        @{
            number = 3; title = 'Three'; url = 'https://github.com/owner/name/issues/3'; body = 'Body 3'
            labels = @(@{ name = 'bug' }); assignees = @(@{ login = 'carol' })
            comments = @(@{ author = @{ login = 'alice' }; body = 'Hi'; createdAt = '2026-01-01T10:00:00Z' })
        }
        @{ number = 2; title = 'Two'; url = 'https://github.com/owner/name/issues/2'; body = ''; labels = @(); assignees = @(); comments = @() }
    )
}

Describe 'get-issues.ps1' {
    It 'lists open issues by default, with their labels, assignees and comments (<_>)' -ForEach 'pwsh', 'powershell' {
        Set-GhStub @(@{ match = '^issue list --repo owner/name --state open --limit 100 --json \S+$'; stdout = $script:issues })

        $run = Invoke-SkillScript 'get-issues' @{ Repository = $script:repo } -Shell $_

        $run.ExitCode | Should -Be 0 -Because $run.Stderr
        $run.Result.number | Should -Be @(3, 2)
        $run.Result[0].labels | Should -Be 'bug'
        $run.Result[0].assignees | Should -Be 'carol'
        $run.Result[0].comments[0].author | Should -Be 'alice'
        $run.Result[0].comments[0].body | Should -Be 'Hi'
        , $run.Result[1].labels | Should -BeOfType [array]
        , $run.Result[1].comments | Should -BeOfType [array]
    }

    It 'passes the state, every label and the limit to gh' {
        Set-GhStub @(@{ match = '^issue list '; stdout = @() })

        $run = Invoke-SkillScript 'get-issues' @{ Repository = $script:repo; State = 'all'; Label = 'bug,ready-for-agent'; Limit = 5 }

        $run.ExitCode | Should -Be 0 -Because $run.Stderr
        $run.ResultLines | Should -Be 1
        , $run.Result | Should -BeOfType [array]
        $run.Result.Count | Should -Be 0
        ((Get-GhCalls).args -join ' ') | Should -Match '--state all --limit 5 .* --label bug --label ready-for-agent$'
    }

    It 'exits 20 when gh fails' {
        Set-GhStub @(@{ match = '^issue list '; stderr = 'GraphQL: Could not resolve to a Repository'; exit = 1 })

        $run = Invoke-SkillScript 'get-issues' @{ Repository = $script:repo }

        $run.ExitCode | Should -Be 20
        $run.Stderr | Should -BeLike '*Could not resolve*'
    }
}
