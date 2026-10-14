BeforeAll {
    $script:frontmatterTests = Join-Path $PSScriptRoot 'skill-frontmatter.Tests.ps1'

    function New-Skill([string] $SkillsRoot, [string] $Folder, [string] $Frontmatter) {
        $dir = New-Item -ItemType Directory -Force -Path (Join-Path $SkillsRoot $Folder)
        Set-Content -LiteralPath (Join-Path $dir 'SKILL.md') -Value "---`n$Frontmatter`n---`n`nBody." -Encoding utf8
    }

    # A separate process keeps the nested Pester run from interfering with this one.
    function Invoke-FrontmatterTests([string] $SkillsRoot) {
        # Without its file, Pester would fall back to running the current folder, this file included.
        if (-not (Test-Path -LiteralPath $script:frontmatterTests)) { throw "Not found: $script:frontmatterTests" }
        pwsh -NoProfile -Command {
            param($TestsPath, $SkillsRoot)
            $container = New-PesterContainer -Path $TestsPath -Data @{ SkillsRoot = $SkillsRoot }
            $result = Invoke-Pester -Container $container -PassThru -Output None
            $result.Tests | ForEach-Object {
                [pscustomobject] @{
                    Name    = $_.ExpandedName
                    Result  = "$($_.Result)"
                    Message = ($_.ErrorRecord | ForEach-Object { $_.Exception.Message }) -join "`n"
                }
            }
        } -args $script:frontmatterTests, $SkillsRoot
    }

    $skillsRoot = Join-Path $TestDrive 'skills'
    New-Skill $skillsRoot 'valid' "name: valid`ndescription: Use when testing a valid skill."
    New-Skill $skillsRoot 'invalid-yaml' "name: invalid-yaml`ndescription: Use when testing: an unquoted colon."
    New-Skill $skillsRoot 'wrong-name' "name: other-name`ndescription: Use when testing a renamed skill."
    New-Skill $skillsRoot 'missing-description' 'name: missing-description'
    New-Skill $skillsRoot 'empty-description' "name: empty-description`ndescription: `"`""
    New-Skill $skillsRoot 'no-use-when' "name: no-use-when`ndescription: Tests a skill without the leading phrase."

    $script:results = Invoke-FrontmatterTests $skillsRoot
}

Describe 'skill-frontmatter.Tests.ps1 on broken fixtures' {
    It 'runs one test case per skill' {
        $script:results.Name | Sort-Object | Should -Be @(
            'empty-description', 'invalid-yaml', 'missing-description', 'no-use-when', 'valid', 'wrong-name'
        )
    }

    It 'passes a valid skill' {
        ($script:results | Where-Object Name -EQ 'valid').Result | Should -Be 'Passed'
    }

    It 'fails <skill> with a message containing "<expected>"' -ForEach @(
        @{ skill = 'invalid-yaml'; expected = 'not valid YAML' }
        @{ skill = 'invalid-yaml'; expected = 'mapping' }
        @{ skill = 'wrong-name'; expected = 'other-name' }
        @{ skill = 'missing-description'; expected = 'description' }
        @{ skill = 'empty-description'; expected = 'description' }
        @{ skill = 'no-use-when'; expected = 'docs/guidelines/index.md' }
    ) {
        $result = $script:results | Where-Object Name -EQ $skill

        $result.Result | Should -Be 'Failed'
        $result.Message | Should -BeLike "*$expected*"
    }
}
