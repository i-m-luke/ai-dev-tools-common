BeforeAll {
    $script:updateToc = Join-Path $PSScriptRoot '..' '..' '..' 'skills' 'document-app' 'scripts' 'update-toc.ps1'

    function New-Document([string] $Content) {
        $path = Join-Path $TestDrive "$([guid]::NewGuid()).md"
        [IO.File]::WriteAllText($path, $Content, [Text.UTF8Encoding]::new($false))
        $path
    }

    function Invoke-UpdateToc([string] $Path) {
        $stdout = pwsh -NoProfile -File $script:updateToc -Path $Path 2>$null
        $line = @($stdout | Where-Object { $_ -like '::result::*' })
        [pscustomobject] @{
            ExitCode = $LASTEXITCODE
            Result   = if ($line.Count -eq 1) { $line[0].Substring(10) | ConvertFrom-Json }
        }
    }
}

Describe 'update-toc.ps1' {
    Context 'Updating' {
        It 'adds missing ASCII anchors and rebuilds the TOC by the heading hierarchy' {
            $path = New-Document (@(
                '# App', '', '## Obsah', '', '<!--TOC-->', '- stale', '<!--/TOC-->', '',
                '## Hlavní okno', '', '### Panel nástrojů {#toolbar}', '', '## Nastavení aplikace', ''
            ) -join "`n")

            $run = Invoke-UpdateToc $path

            $run.ExitCode | Should -Be 0
            $run.Result.headings | Should -Be 3
            $run.Result.addedAnchors | Should -Be @('hlavni-okno', 'nastaveni-aplikace')
            [IO.File]::ReadAllText($path) | Should -Be (@(
                '# App', '', '## Obsah', '', '<!--TOC-->', '',
                '- [Hlavní okno](#hlavni-okno)', '  - [Panel nástrojů](#toolbar)', '- [Nastavení aplikace](#nastaveni-aplikace)',
                '', '<!--/TOC-->', '',
                '## Hlavní okno {#hlavni-okno}', '', '### Panel nástrojů {#toolbar}', '', '## Nastavení aplikace {#nastaveni-aplikace}', ''
            ) -join "`n")
        }

        It 'makes a generated anchor unique' {
            $path = New-Document "<!--TOC-->`n<!--/TOC-->`n## Export {#export}`n## Export`n## Export`n"

            (Invoke-UpdateToc $path).Result.addedAnchors | Should -Be @('export-2', 'export-3')
        }

        It 'skips headings in fenced code blocks' {
            $path = New-Document "<!--TOC-->`n<!--/TOC-->`n## Real`n``````n## Not a heading`n``````n"

            (Invoke-UpdateToc $path).Result.headings | Should -Be 1
        }

        It 'reports links whose anchor no heading carries' {
            $path = New-Document "<!--TOC-->`n<!--/TOC-->`n## Main {#main}`nSee [Main](#main) and [Gone](#gone).`n"

            $run = Invoke-UpdateToc $path

            $run.ExitCode | Should -Be 0
            $run.Result.brokenLinks | Should -Be @('gone')
        }

        It 'keeps CRLF line endings' {
            $path = New-Document "<!--TOC-->`r`n<!--/TOC-->`r`n## Main`r`n"

            Invoke-UpdateToc $path | Out-Null

            [IO.File]::ReadAllText($path) | Should -Be "<!--TOC-->`r`n`r`n- [Main](#main)`r`n`r`n<!--/TOC-->`r`n## Main {#main}`r`n"
        }
    }

    Context 'Failures' {
        It 'exits 2 when the document does not exist' {
            (Invoke-UpdateToc (Join-Path $TestDrive 'missing.md')).ExitCode | Should -Be 2
        }

        It 'exits 3 when <case>' -ForEach @(
            @{ case = 'the markers are missing'; content = "## Main`n" }
            @{ case = 'the markers are swapped'; content = "<!--/TOC-->`n<!--TOC-->`n## Main`n" }
        ) {
            (Invoke-UpdateToc (New-Document $content)).ExitCode | Should -Be 3
        }
    }
}
