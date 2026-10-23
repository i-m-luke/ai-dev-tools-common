BeforeAll {
    . (Join-Path $PSScriptRoot 'gh-test-helpers.ps1')
    $script:block = Get-ApiMatch POST 'repos/owner/name/issues/2/dependencies/blocked_by'
    $script:issues = @(
        @{ match = Get-ApiMatch GET 'repos/owner/name/issues/2'; stdout = New-RestIssue -Number 2 }
        @{ match = Get-ApiMatch GET 'repos/owner/name/issues/3'; stdout = New-RestIssue -Number 3 }
    )
}

Describe 'add-blocker.ps1' {
    It "adds the dependency by the blocker's database id (<_>)" -ForEach 'pwsh', 'powershell' {
        Set-GhStub ($script:issues + @(@{ match = $script:block; stdout = New-RestIssue -Number 2 }))

        $run = Invoke-SkillScript 'add-blocker' @{ Repository = $script:repo; Issue = 2; BlockedBy = 3 } -Shell $_

        $run.ExitCode | Should -Be 0 -Because $run.Stderr
        $run.ResultLines | Should -Be 0
        (Get-GhBody $script:block).issue_id | Should -Be 1003
    }

    It 'exits 21 when issue dependencies are not available' {
        Set-GhStub ($script:issues + @($script:notFound + @{ match = $script:block }))

        $run = Invoke-SkillScript 'add-blocker' @{ Repository = $script:repo; Issue = 2; BlockedBy = 3 }

        $run.ExitCode | Should -Be 21
        $run.Stderr | Should -BeLike '*dependencies are not available*'
    }

    It 'exits 20 when the blocker does not exist' {
        Set-GhStub @($script:issues[0]; $script:notFound + @{ match = Get-ApiMatch GET 'repos/owner/name/issues/3' })

        $run = Invoke-SkillScript 'add-blocker' @{ Repository = $script:repo; Issue = 2; BlockedBy = 3 }

        $run.ExitCode | Should -Be 20
        @(Get-GhCalls | Where-Object { $_.args -contains 'POST' }).Count | Should -Be 0
    }
}
