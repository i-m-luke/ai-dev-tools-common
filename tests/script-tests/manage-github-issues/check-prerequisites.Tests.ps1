BeforeAll {
    . (Join-Path $PSScriptRoot 'gh-test-helpers.ps1')
    $script:accessibleRepo = @(
        @{ match = '^auth status --hostname github\.com$' }
        @{ match = '^api repos/owner/name$'; stdout = @{ has_issues = $true } }
    )
}

Describe 'check-prerequisites.ps1' {
    It 'exits 0 when gh is logged in and the repository has issues (<_>)' -ForEach 'pwsh', 'powershell' {
        Set-GhStub $script:accessibleRepo

        $run = Invoke-SkillScript 'check-prerequisites' @{ Repository = $script:repo } -Shell $_

        $run.ExitCode | Should -Be 0 -Because $run.Stderr
        $run.ResultLines | Should -Be 0
    }

    It 'exits 2 when gh is not installed' {
        $run = Invoke-SkillScript 'check-prerequisites' @{ Repository = $script:repo } -WithoutGh

        $run.ExitCode | Should -Be 2
        $run.Stderr | Should -BeLike '*https://cli.github.com*'
    }

    It 'exits 3 when gh is not logged in' {
        Set-GhStub @(@{ match = '^auth status'; stderr = 'You are not logged into any GitHub hosts.'; exit = 1 })

        $run = Invoke-SkillScript 'check-prerequisites' @{ Repository = $script:repo }

        $run.ExitCode | Should -Be 3
        $run.Stderr | Should -BeLike '*gh auth login*'
    }

    It 'exits 4 when the repository is not accessible' {
        Set-GhStub @(
            @{ match = '^auth status' }
            $script:notFound + @{ match = '^api repos/owner/name$' }
        )

        $run = Invoke-SkillScript 'check-prerequisites' @{ Repository = $script:repo }

        $run.ExitCode | Should -Be 4
        $run.Stderr | Should -BeLike '*owner/name*HTTP 404*'
    }

    It 'exits 4 when the repository has issues disabled' {
        Set-GhStub @(
            @{ match = '^auth status' }
            @{ match = '^api repos/owner/name$'; stdout = @{ has_issues = $false } }
        )

        $run = Invoke-SkillScript 'check-prerequisites' @{ Repository = $script:repo }

        $run.ExitCode | Should -Be 4
        $run.Stderr | Should -BeLike '*issues disabled*'
    }
}
