BeforeAll {
    . (Join-Path $PSScriptRoot 'gh-test-helpers.ps1')
    $script:create = Get-ApiMatch POST 'repos/owner/name/issues'
}

Describe 'new-issue.ps1' {
    It 'creates the issue with the title, body and labels and returns its number and URL (<_>)' -ForEach 'pwsh', 'powershell' {
        Set-GhStub @(@{ match = $script:create; stdout = New-RestIssue -Number 12 })
        $body = New-TextFile "## Popis`n`n„Uvozovky“ a `"quotes`""

        $run = Invoke-SkillScript 'new-issue' @{ Repository = $script:repo; Title = 'A title'; BodyPath = $body; Label = 'bug, needs-triage' } -Shell $_

        $run.ExitCode | Should -Be 0 -Because $run.Stderr
        $run.Result.number | Should -Be 12
        $run.Result.url | Should -Be 'https://github.com/owner/name/issues/12'
        $sent = Get-GhBody $script:create
        $sent.title | Should -Be 'A title'
        $sent.body | Should -Be "## Popis`n`n„Uvozovky“ a `"quotes`""
        $sent.labels | Should -Be @('bug', 'needs-triage')
    }

    It 'sends no labels when none are given' {
        Set-GhStub @(@{ match = $script:create; stdout = New-RestIssue -Number 12 })

        $run = Invoke-SkillScript 'new-issue' @{ Repository = $script:repo; Title = 'A title'; BodyPath = (New-TextFile 'body') }

        $run.ExitCode | Should -Be 0 -Because $run.Stderr
        (Get-GhBody $script:create).PSObject.Properties.Name | Should -Not -Contain 'labels'
    }

    It 'exits 20 when GitHub rejects the issue' {
        Set-GhStub @(@{ match = $script:create; stderr = 'gh: Validation Failed (HTTP 422)'; exit = 1 })

        $run = Invoke-SkillScript 'new-issue' @{ Repository = $script:repo; Title = 'A title'; BodyPath = (New-TextFile 'body') }

        $run.ExitCode | Should -Be 20
        $run.Stderr | Should -BeLike '*HTTP 422*'
    }

    It 'exits 1 when the body file does not exist' {
        Set-GhStub @()

        $run = Invoke-SkillScript 'new-issue' @{ Repository = $script:repo; Title = 'A title'; BodyPath = (Join-Path $TestDrive 'missing.md') }

        $run.ExitCode | Should -Be 1
        Get-GhCalls | Should -BeNullOrEmpty
    }
}
