BeforeAll {
    . (Join-Path $PSScriptRoot 'gh-test-helpers.ps1')
    $script:post = Get-ApiMatch POST 'repos/owner/name/issues/7/comments'
}

Describe 'add-comment.ps1' {
    It 'posts the comment from the file and returns its URL (<_>)' -ForEach 'pwsh', 'powershell' {
        Set-GhStub @(@{ match = $script:post; stdout = @{ html_url = 'https://github.com/owner/name/issues/7#issuecomment-1' } })

        $run = Invoke-SkillScript 'add-comment' @{ Repository = $script:repo; Number = 7; BodyPath = (New-TextFile "Řešení:`n- hotovo") } -Shell $_

        $run.ExitCode | Should -Be 0 -Because $run.Stderr
        $run.Result.url | Should -Be 'https://github.com/owner/name/issues/7#issuecomment-1'
        (Get-GhBody $script:post).body | Should -Be "Řešení:`n- hotovo"
    }

    It 'exits 2 when no item has the number' {
        Set-GhStub @($script:notFound + @{ match = $script:post })

        $run = Invoke-SkillScript 'add-comment' @{ Repository = $script:repo; Number = 7; BodyPath = (New-TextFile 'x') }

        $run.ExitCode | Should -Be 2
        $run.Stderr | Should -BeLike '*HTTP 404*'
    }
}
