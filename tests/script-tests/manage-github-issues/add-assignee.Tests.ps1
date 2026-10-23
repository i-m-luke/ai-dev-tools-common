BeforeAll {
    . (Join-Path $PSScriptRoot 'gh-test-helpers.ps1')
    $script:assign = Get-ApiMatch POST 'repos/owner/name/issues/7/assignees'
}

Describe 'add-assignee.ps1' {
    It 'assigns the logged-in account by default (<_>)' -ForEach 'pwsh', 'powershell' {
        Set-GhStub @(
            @{ match = Get-ApiMatch GET 'user'; stdout = @{ login = 'me' } }
            @{ match = $script:assign; stdout = New-RestIssue -Number 7 -Assignees 'me' }
        )

        $run = Invoke-SkillScript 'add-assignee' @{ Repository = $script:repo; Number = 7 } -Shell $_

        $run.ExitCode | Should -Be 0 -Because $run.Stderr
        $run.Result.assignees | Should -Be 'me'
        (Get-GhBody $script:assign).assignees | Should -Be 'me'
    }

    It 'assigns the given login' {
        Set-GhStub @(@{ match = $script:assign; stdout = New-RestIssue -Number 7 -Assignees 'carol', 'dave' })

        $run = Invoke-SkillScript 'add-assignee' @{ Repository = $script:repo; Number = 7; Assignee = 'dave' }

        $run.ExitCode | Should -Be 0 -Because $run.Stderr
        $run.Result.assignees | Should -Be @('carol', 'dave')
        (Get-GhBody $script:assign).assignees | Should -Be 'dave'
    }

    It 'exits 21 when GitHub skips the user' {
        Set-GhStub @(@{ match = $script:assign; stdout = New-RestIssue -Number 7 })

        $run = Invoke-SkillScript 'add-assignee' @{ Repository = $script:repo; Number = 7; Assignee = 'stranger' }

        $run.ExitCode | Should -Be 21
        $run.Stderr | Should -BeLike '*stranger*'
    }

    It 'exits 20 when no item has the number' {
        Set-GhStub @($script:notFound + @{ match = $script:assign })

        $run = Invoke-SkillScript 'add-assignee' @{ Repository = $script:repo; Number = 7; Assignee = 'dave' }

        $run.ExitCode | Should -Be 20
    }
}
