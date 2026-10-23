BeforeAll {
    . (Join-Path $PSScriptRoot 'gh-test-helpers.ps1')
    $script:comments = @(
        @{ user = @{ login = 'alice' }; body = 'First'; created_at = '2026-01-01T10:00:00Z' }
        @{ user = @{ login = 'bob' }; body = 'Second'; created_at = '2026-01-02T10:00:00Z' }
    )
}

Describe 'get-item.ps1' {
    It 'reads an issue with its labels, assignees and comments (<_>)' -ForEach 'pwsh', 'powershell' {
        Set-GhStub @(
            @{ match = (Get-ApiMatch GET 'repos/owner/name/issues/7'); stdout = New-RestIssue -Number 7 -Labels 'bug' -Assignees 'carol' }
            @{ match = (Get-ApiMatch GET 'repos/owner/name/issues/7/comments'); stdout = $script:comments }
        )

        $run = Invoke-SkillScript 'get-item' @{ Repository = $script:repo; Number = 7 } -Shell $_

        $run.ExitCode | Should -Be 0 -Because $run.Stderr
        $run.Result.kind | Should -Be 'issue'
        $run.Result.number | Should -Be 7
        $run.Result.title | Should -Be 'Title 7'
        $run.Result.state | Should -Be 'open'
        $run.Result.author | Should -Be 'author'
        $run.Result.body | Should -Be 'Body 7'
        , $run.Result.labels | Should -Be @('bug')
        , $run.Result.assignees | Should -Be @('carol')
        $run.Result.comments.author | Should -Be @('alice', 'bob')
        $run.Result.comments[1].body | Should -Be 'Second'
        $run.Result.comments[1].createdAt | Should -Not -BeNullOrEmpty
        $run.Result.PSObject.Properties.Name | Should -Not -Contain 'diff'
    }

    It 'reads a pull request with its diff' {
        Set-GhStub @(
            @{ match = (Get-ApiMatch GET 'repos/owner/name/issues/5'); stdout = New-RestIssue -Number 5 -PullRequest }
            @{ match = (Get-ApiMatch GET 'repos/owner/name/issues/5/comments'); stdout = @() }
            @{ match = '^pr diff 5 --repo owner/name$'; stdout = "diff --git a/x b/x`n+added" }
        )

        $run = Invoke-SkillScript 'get-item' @{ Repository = $script:repo; Number = 5 }

        $run.ExitCode | Should -Be 0 -Because $run.Stderr
        $run.Result.kind | Should -Be 'pr'
        $run.Result.diff | Should -Be "diff --git a/x b/x`n+added"
        , $run.Result.comments | Should -BeOfType [array]
        $run.Result.comments.Count | Should -Be 0
    }

    It 'exits 20 when no item has the number' {
        Set-GhStub @($script:notFound + @{ match = (Get-ApiMatch GET 'repos/owner/name/issues/9') })

        $run = Invoke-SkillScript 'get-item' @{ Repository = $script:repo; Number = 9 }

        $run.ExitCode | Should -Be 20
        $run.Stderr | Should -BeLike '*#9*HTTP 404*'
    }
}
