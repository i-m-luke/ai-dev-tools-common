BeforeAll {
    . (Join-Path $PSScriptRoot 'gh-test-helpers.ps1')
    $script:module = Join-Path $script:scriptsDir 'github-client.psm1'

    # Runs a command against github-client.psm1 in a child pwsh, with the stub first on PATH.
    function Invoke-Module([string] $Command) {
        $originalPath = $env:PATH
        $env:PATH = $script:stubDir + [IO.Path]::PathSeparator + $originalPath
        try {
            pwsh -NoProfile -Command "`$ErrorActionPreference = 'Stop'; Import-Module '$script:module'; $Command" 2>$null
        } finally {
            $env:PATH = $originalPath
        }
    }
}

Describe 'github-client.psm1' {
    It 'reads every page of a paginated list' {
        $firstPage = @(1..100 | ForEach-Object { @{ n = $_ } })
        Set-GhStub @(
            @{ match = 'items\?per_page=100&page=1$'; stdout = $firstPage }
            @{ match = 'items\?per_page=100&page=2$'; stdout = @(@{ n = 101 }) }
        )

        $count = Invoke-Module "@(Get-GhApiPages -Path 'items' -Action 'list').Count"

        $count | Should -Be 101
        @(Get-GhCalls).Count | Should -Be 2
    }

    It 'stops reading pages at the limit' {
        Set-GhStub @(@{ match = 'items\?state=open&per_page=100&page=1$'; stdout = @(1..100 | ForEach-Object { @{ n = $_ } }) })

        $count = Invoke-Module "@(Get-GhApiPages -Path 'items?state=open' -Action 'list' -Limit 5).Count"

        $count | Should -Be 5
        @(Get-GhCalls).Count | Should -Be 1
    }

    It 'returns nothing for an HTTP 404 with -IgnoreNotFound' {
        Set-GhStub @($script:notFound + @{ match = 'missing' })

        $output = Invoke-Module "`$r = Invoke-GhApi -Path 'missing' -Method DELETE -Action 'delete' -IgnoreNotFound; 'returned:' + (`$null -eq `$r)"

        $output | Should -Be 'returned:True'
    }

    It 'sends the body as JSON on stdin' {
        Set-GhStub @(@{ match = '^api --method POST things --input -$'; stdout = @{ ok = $true } })

        Invoke-Module "(Invoke-GhApi -Path 'things' -Method POST -Body @{ name = 'x' } -Action 'post').ok" | Should -Be 'True'

        (Get-GhBody 'things').name | Should -Be 'x'
    }

    It 'writes an empty list as an empty JSON array' {
        Invoke-Module 'Write-Result @()' | Should -Be '::result::[]'
    }

    It 'splits a comma-separated list into trimmed items' {
        Invoke-Module "(Split-List ' a, b ,,c ') -join '|'" | Should -Be 'a|b|c'
    }
}
