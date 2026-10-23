BeforeAll {
    . (Join-Path $PSScriptRoot 'gh-test-helpers.ps1')
    $script:patch = Get-ApiMatch PATCH 'repos/owner/name/issues/7'
}

Describe 'update-issue.ps1' {
    It 'replaces the title and the body (<_>)' -ForEach 'pwsh', 'powershell' {
        Set-GhStub @(@{ match = $script:patch; stdout = New-RestIssue -Number 7 })

        $run = Invoke-SkillScript 'update-issue' @{ Repository = $script:repo; Number = 7; Title = 'New title'; BodyPath = (New-TextFile "## Decisions`n- one") } -Shell $_

        $run.ExitCode | Should -Be 0 -Because $run.Stderr
        $run.Result.number | Should -Be 7
        $run.Result.url | Should -Be 'https://github.com/owner/name/issues/7'
        $sent = Get-GhBody $script:patch
        $sent.title | Should -Be 'New title'
        $sent.body | Should -Be "## Decisions`n- one"
    }

    It 'leaves the title as it is when only the body is given' {
        Set-GhStub @(@{ match = $script:patch; stdout = New-RestIssue -Number 7 })

        $run = Invoke-SkillScript 'update-issue' @{ Repository = $script:repo; Number = 7; BodyPath = (New-TextFile 'body') }

        $run.ExitCode | Should -Be 0 -Because $run.Stderr
        (Get-GhBody $script:patch).PSObject.Properties.Name | Should -Be 'body'
    }

    It 'exits 1 without calling GitHub when neither a title nor a body is given' {
        Set-GhStub @()

        $run = Invoke-SkillScript 'update-issue' @{ Repository = $script:repo; Number = 7 }

        $run.ExitCode | Should -Be 1
        $run.Stderr | Should -BeLike '*-Title*-BodyPath*'
        Get-GhCalls | Should -BeNullOrEmpty
    }

    It 'exits 20 when no item has the number' {
        Set-GhStub @($script:notFound + @{ match = $script:patch })

        $run = Invoke-SkillScript 'update-issue' @{ Repository = $script:repo; Number = 7; Title = 'x' }

        $run.ExitCode | Should -Be 20
    }
}
