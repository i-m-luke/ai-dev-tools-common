BeforeAll {
    . (Join-Path $PSScriptRoot 'gh-test-helpers.ps1')
    $script:link = Get-ApiMatch POST 'repos/owner/name/issues/1/sub_issues'
    $script:issues = @(
        @{ match = Get-ApiMatch GET 'repos/owner/name/issues/1'; stdout = New-RestIssue -Number 1 }
        @{ match = Get-ApiMatch GET 'repos/owner/name/issues/2'; stdout = New-RestIssue -Number 2 }
    )
}

Describe 'add-sub-issue.ps1' {
    It "links the child under the parent by the child's database id (<_>)" -ForEach 'pwsh', 'powershell' {
        Set-GhStub ($script:issues + @(@{ match = $script:link; stdout = New-RestIssue -Number 1 }))

        $run = Invoke-SkillScript 'add-sub-issue' @{ Repository = $script:repo; Parent = 1; Child = 2 } -Shell $_

        $run.ExitCode | Should -Be 0 -Because $run.Stderr
        $run.ResultLines | Should -Be 0
        (Get-GhBody $script:link).sub_issue_id | Should -Be 1002
    }

    It 'exits 21 when sub-issues are not available' {
        Set-GhStub ($script:issues + @($script:notFound + @{ match = $script:link }))

        $run = Invoke-SkillScript 'add-sub-issue' @{ Repository = $script:repo; Parent = 1; Child = 2 }

        $run.ExitCode | Should -Be 21
        $run.Stderr | Should -BeLike '*Sub-issues are not available*'
    }

    It 'exits 20 when an issue does not exist' {
        Set-GhStub @($script:issues[0]; $script:notFound + @{ match = Get-ApiMatch GET 'repos/owner/name/issues/2' })

        $run = Invoke-SkillScript 'add-sub-issue' @{ Repository = $script:repo; Parent = 1; Child = 2 }

        $run.ExitCode | Should -Be 20
        @(Get-GhCalls | Where-Object { $_.args -contains 'POST' }).Count | Should -Be 0
    }

    It 'exits 20 when GitHub rejects the link' {
        Set-GhStub ($script:issues + @(@{ match = $script:link; stderr = 'gh: An issue can only have one parent (HTTP 422)'; exit = 1 }))

        $run = Invoke-SkillScript 'add-sub-issue' @{ Repository = $script:repo; Parent = 1; Child = 2 }

        $run.ExitCode | Should -Be 20
        $run.Stderr | Should -BeLike '*one parent*'
    }
}
