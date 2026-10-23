BeforeAll {
    . (Join-Path $PSScriptRoot 'gh-test-helpers.ps1')
    $script:parent = @{ match = Get-ApiMatch GET 'repos/owner/name/issues/1'; stdout = New-RestIssue -Number 1 }
    $script:subIssues = Get-ApiMatch GET 'repos/owner/name/issues/1/sub_issues'
}

Describe 'get-ready-sub-issues.ps1' {
    It 'lists the open, unassigned and unblocked sub-issues in the parent order (<_>)' -ForEach 'pwsh', 'powershell' {
        Set-GhStub @(
            $script:parent
            @{
                match  = $script:subIssues
                stdout = @(
                    New-RestIssue -Number 5
                    New-RestIssue -Number 2 -State closed
                    New-RestIssue -Number 3 -Assignees 'carol'
                    New-RestIssue -Number 4 -OpenBlockers 1
                    New-RestIssue -Number 6
                )
            }
        )

        $run = Invoke-SkillScript 'get-ready-sub-issues' @{ Repository = $script:repo; Parent = 1 } -Shell $_

        $run.ExitCode | Should -Be 0 -Because $run.Stderr
        $run.Result.number | Should -Be @(5, 6)
        $run.Result[0].title | Should -Be 'Title 5'
        $run.Result[0].url | Should -Be 'https://github.com/owner/name/issues/5'
    }

    It 'reads the dependencies of a sub-issue the list returns without them' {
        $child = New-RestIssue -Number 4
        $child.Remove('issue_dependencies_summary')
        Set-GhStub @(
            $script:parent
            @{ match = $script:subIssues; stdout = @($child) }
            @{ match = Get-ApiMatch GET 'repos/owner/name/issues/4'; stdout = New-RestIssue -Number 4 -OpenBlockers 2 }
        )

        $run = Invoke-SkillScript 'get-ready-sub-issues' @{ Repository = $script:repo; Parent = 1 }

        $run.ExitCode | Should -Be 0 -Because $run.Stderr
        $run.ResultLines | Should -Be 1
        $run.Result.Count | Should -Be 0
    }

    It 'exits 21 when sub-issues are not available' {
        Set-GhStub @($script:parent; $script:notFound + @{ match = $script:subIssues })

        $run = Invoke-SkillScript 'get-ready-sub-issues' @{ Repository = $script:repo; Parent = 1 }

        $run.ExitCode | Should -Be 21
        $run.Stderr | Should -BeLike '*Sub-issues are not available*'
    }

    It 'exits 20 when the parent does not exist' {
        Set-GhStub @($script:notFound + @{ match = Get-ApiMatch GET 'repos/owner/name/issues/1' })

        $run = Invoke-SkillScript 'get-ready-sub-issues' @{ Repository = $script:repo; Parent = 1 }

        $run.ExitCode | Should -Be 20
    }
}
