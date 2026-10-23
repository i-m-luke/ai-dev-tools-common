BeforeAll {
    . (Join-Path $PSScriptRoot 'gh-test-helpers.ps1')
    $script:comment = Get-ApiMatch POST 'repos/owner/name/issues/7/comments'
    $script:closeIssue = Get-ApiMatch PATCH 'repos/owner/name/issues/7'
}

Describe 'close-item.ps1' {
    It 'comments on the issue, then closes it as completed (<_>)' -ForEach 'pwsh', 'powershell' {
        Set-GhStub @(
            @{ match = Get-ApiMatch GET 'repos/owner/name/issues/7'; stdout = New-RestIssue -Number 7 }
            @{ match = $script:comment; stdout = @{ html_url = 'u' } }
            @{ match = $script:closeIssue; stdout = New-RestIssue -Number 7 -State closed }
        )

        $run = Invoke-SkillScript 'close-item' @{ Repository = $script:repo; Number = 7; CommentPath = (New-TextFile 'Done.') } -Shell $_

        $run.ExitCode | Should -Be 0 -Because $run.Stderr
        $run.Result.number | Should -Be 7
        $run.Result.kind | Should -Be 'issue'
        (Get-GhBody $script:comment).body | Should -Be 'Done.'
        $sent = Get-GhBody $script:closeIssue
        $sent.state | Should -Be 'closed'
        $sent.state_reason | Should -Be 'completed'
        $calls = @(Get-GhCalls | ForEach-Object { $_.args -join ' ' })
        [array]::FindIndex($calls, [Predicate[string]] { $args[0] -match $script:comment }) |
            Should -BeLessThan ([array]::FindIndex($calls, [Predicate[string]] { $args[0] -match $script:closeIssue }))
    }

    It 'closes an issue as not planned without a comment' {
        Set-GhStub @(
            @{ match = Get-ApiMatch GET 'repos/owner/name/issues/7'; stdout = New-RestIssue -Number 7 }
            @{ match = $script:closeIssue; stdout = New-RestIssue -Number 7 -State closed }
        )

        $run = Invoke-SkillScript 'close-item' @{ Repository = $script:repo; Number = 7; Reason = 'not_planned' }

        $run.ExitCode | Should -Be 0 -Because $run.Stderr
        (Get-GhBody $script:closeIssue).state_reason | Should -Be 'not_planned'
        @(Get-GhCalls | Where-Object { $_.args -contains 'POST' }).Count | Should -Be 0
    }

    It 'closes a pull request through the pulls endpoint' {
        $closePull = Get-ApiMatch PATCH 'repos/owner/name/pulls/5'
        Set-GhStub @(
            @{ match = Get-ApiMatch GET 'repos/owner/name/issues/5'; stdout = New-RestIssue -Number 5 -PullRequest }
            @{ match = $closePull; stdout = @{ number = 5; state = 'closed' } }
        )

        $run = Invoke-SkillScript 'close-item' @{ Repository = $script:repo; Number = 5 }

        $run.ExitCode | Should -Be 0 -Because $run.Stderr
        $run.Result.kind | Should -Be 'pr'
        (Get-GhBody $closePull).state | Should -Be 'closed'
    }

    It 'exits 20 when no item has the number' {
        Set-GhStub @($script:notFound + @{ match = Get-ApiMatch GET 'repos/owner/name/issues/7' })

        $run = Invoke-SkillScript 'close-item' @{ Repository = $script:repo; Number = 7; CommentPath = (New-TextFile 'Done.') }

        $run.ExitCode | Should -Be 20
        @(Get-GhCalls | Where-Object { $_.args -contains 'POST' }).Count | Should -Be 0
    }
}
