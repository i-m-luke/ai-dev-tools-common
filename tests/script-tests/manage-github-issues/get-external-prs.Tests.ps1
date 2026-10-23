BeforeAll {
    . (Join-Path $PSScriptRoot 'gh-test-helpers.ps1')

    function New-RestPull([int] $Number, [string] $Association) {
        @{
            number = $Number; title = "PR $Number"; html_url = "https://github.com/owner/name/pull/$Number"; body = "Body $Number"
            user = @{ login = "user$Number" }; author_association = $Association; labels = @(@{ name = 'enhancement' })
        }
    }
}

Describe 'get-external-prs.ps1' {
    It 'lists only pull requests of external contributors, with their comments (<_>)' -ForEach 'pwsh', 'powershell' {
        Set-GhStub @(
            @{
                match  = Get-ApiMatch GET 'repos/owner/name/pulls'
                stdout = @(
                    New-RestPull 1 'OWNER'; New-RestPull 2 'CONTRIBUTOR'; New-RestPull 3 'MEMBER'
                    New-RestPull 4 'FIRST_TIME_CONTRIBUTOR'; New-RestPull 5 'COLLABORATOR'; New-RestPull 6 'NONE'
                )
            }
            @{
                match  = '^api --method GET repos/owner/name/issues/\d+/comments'
                stdout = @(@{ user = @{ login = 'alice' }; body = 'Thanks'; created_at = '2026-01-01T10:00:00Z' })
            }
        )

        $run = Invoke-SkillScript 'get-external-prs' @{ Repository = $script:repo } -Shell $_

        $run.ExitCode | Should -Be 0 -Because $run.Stderr
        $run.Result.number | Should -Be @(2, 4, 6)
        $run.Result[0].author | Should -Be 'user2'
        $run.Result[0].authorAssociation | Should -Be 'CONTRIBUTOR'
        $run.Result[0].labels | Should -Be 'enhancement'
        $run.Result[0].comments[0].body | Should -Be 'Thanks'
        ((Get-GhCalls).args -join ' ') | Should -Match 'pulls\?state=open&per_page=100&page=1'
    }

    It 'returns an empty list when there are no external pull requests' {
        Set-GhStub @(@{ match = Get-ApiMatch GET 'repos/owner/name/pulls'; stdout = @(New-RestPull 1 'OWNER') })

        $run = Invoke-SkillScript 'get-external-prs' @{ Repository = $script:repo }

        $run.ExitCode | Should -Be 0 -Because $run.Stderr
        $run.ResultLines | Should -Be 1
        $run.Result.Count | Should -Be 0
    }

    It 'exits 20 when GitHub rejects the request' {
        Set-GhStub @($script:notFound + @{ match = Get-ApiMatch GET 'repos/owner/name/pulls' })

        $run = Invoke-SkillScript 'get-external-prs' @{ Repository = $script:repo }

        $run.ExitCode | Should -Be 20
    }
}
