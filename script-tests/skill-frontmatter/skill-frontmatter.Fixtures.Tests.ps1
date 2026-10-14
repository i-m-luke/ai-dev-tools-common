BeforeAll {
    $script:frontmatterTests = Join-Path $PSScriptRoot 'skill-frontmatter.Tests.ps1'

    function New-Skill([string] $SkillsRoot, [string] $Folder, [string] $Frontmatter, [string] $OpenAiYaml) {
        $dir = New-Item -ItemType Directory -Force -Path (Join-Path $SkillsRoot $Folder)
        Set-Content -LiteralPath (Join-Path $dir 'SKILL.md') -Value "---`n$Frontmatter`n---`n`nBody." -Encoding utf8
        if ($OpenAiYaml) {
            $agents = New-Item -ItemType Directory -Force -Path (Join-Path $dir 'agents')
            Set-Content -LiteralPath (Join-Path $agents 'openai.yaml') -Value $OpenAiYaml -Encoding utf8
        }
    }

    # A separate process keeps the nested Pester run from interfering with this one.
    function Invoke-FrontmatterTests([string] $SkillsRoot, [string] $ImplicitSkillsPath) {
        # Without its file, Pester would fall back to running the current folder, this file included.
        if (-not (Test-Path -LiteralPath $script:frontmatterTests)) { throw "Not found: $script:frontmatterTests" }
        pwsh -NoProfile -Command {
            param($TestsPath, $SkillsRoot, $ImplicitSkillsPath)
            $container = New-PesterContainer -Path $TestsPath -Data @{ SkillsRoot = $SkillsRoot; ImplicitSkillsPath = $ImplicitSkillsPath }
            $result = Invoke-Pester -Container $container -PassThru -Output None
            $result.Tests | ForEach-Object {
                [pscustomobject] @{
                    Block   = $_.Block.Name
                    Name    = $_.ExpandedName
                    Result  = "$($_.Result)"
                    Message = ($_.ErrorRecord | ForEach-Object { $_.Exception.Message }) -join "`n"
                }
            }
        } -args $script:frontmatterTests, $SkillsRoot, $ImplicitSkillsPath
    }

    $explicitPolicy = "policy:`n  allow_implicit_invocation: false"

    $skillsRoot = Join-Path $TestDrive 'skills'
    New-Skill $skillsRoot 'valid' "name: valid`ndescription: Use when testing a valid skill." $explicitPolicy
    New-Skill $skillsRoot 'valid-only' "name: valid-only`ndescription: Use ONLY when testing a valid skill run by other skills."
    New-Skill $skillsRoot 'invalid-yaml' "name: invalid-yaml`ndescription: Use when testing: an unquoted colon."
    New-Skill $skillsRoot 'wrong-name' "name: other-name`ndescription: Use when testing a renamed skill."
    New-Skill $skillsRoot 'missing-description' 'name: missing-description'
    New-Skill $skillsRoot 'empty-description' "name: empty-description`ndescription: `"`""
    New-Skill $skillsRoot 'no-use-when' "name: no-use-when`ndescription: Tests a skill without the leading phrase."
    New-Skill $skillsRoot 'implicit' "name: implicit`ndescription: Use when testing an implicit skill." "interface:`n  display_name: Implicit"
    New-Skill $skillsRoot 'no-openai' "name: no-openai`ndescription: Use when testing a skill without agents/openai.yaml."
    New-Skill $skillsRoot 'approved' "name: approved`ndescription: Use when testing an approved convention skill."
    New-Skill $skillsRoot 'approved-explicit' "name: approved-explicit`ndescription: Use when testing a stale exception." $explicitPolicy
    New-Skill $skillsRoot 'approved-no-reason' "name: approved-no-reason`ndescription: Use when testing an exception without a reason."

    $implicitSkillsPath = Join-Path $TestDrive 'implicit-skills.yaml'
    Set-Content -LiteralPath $implicitSkillsPath -Encoding utf8 -Value @(
        'approved: Convention skill.'
        'approved-explicit: Convention skill.'
        'approved-no-reason:'
        'missing: Convention skill.'
    )

    $script:results = Invoke-FrontmatterTests $skillsRoot $implicitSkillsPath
    $script:frontmatter = $script:results | Where-Object Block -EQ 'Skill frontmatter'
    $script:invocation = $script:results | Where-Object Block -EQ 'Skill invocation'
}

Describe 'skill-frontmatter.Tests.ps1 on frontmatter fixtures' {
    It 'runs one frontmatter test case per skill' {
        $script:frontmatter.Name | Sort-Object | Should -Be @(
            'approved', 'approved-explicit', 'approved-no-reason', 'empty-description', 'implicit', 'invalid-yaml',
            'missing-description', 'no-openai', 'no-use-when', 'valid', 'valid-only', 'wrong-name'
        )
    }

    It 'passes a valid skill <skill>' -ForEach @(
        @{ skill = 'valid' }
        @{ skill = 'valid-only' }
    ) {
        ($script:frontmatter | Where-Object Name -EQ $skill).Result | Should -Be 'Passed'
    }

    It 'fails <skill> with a message containing "<expected>"' -ForEach @(
        @{ skill = 'invalid-yaml'; expected = 'not valid YAML' }
        @{ skill = 'invalid-yaml'; expected = 'mapping' }
        @{ skill = 'wrong-name'; expected = 'other-name' }
        @{ skill = 'missing-description'; expected = 'description' }
        @{ skill = 'empty-description'; expected = 'description' }
        @{ skill = 'no-use-when'; expected = 'docs/guidelines/skills.md' }
    ) {
        $result = $script:frontmatter | Where-Object Name -EQ $skill

        $result.Result | Should -Be 'Failed'
        $result.Message | Should -BeLike "*$expected*"
    }
}

Describe 'skill-frontmatter.Tests.ps1 on invocation fixtures' {
    It 'passes <test>' -ForEach @(
        @{ test = 'valid' }
        @{ test = 'valid-only' }
        @{ test = 'approved' }
        @{ test = 'approved exception approved' }
    ) {
        ($script:invocation | Where-Object Name -EQ $test).Result | Should -Be 'Passed'
    }

    It 'fails <test> with a message containing "<expected>"' -ForEach @(
        @{ test = 'implicit'; expected = 'docs/guidelines/skills.md#invocation' }
        @{ test = 'implicit'; expected = 'implicit-skills.yaml - the list of approved exceptions' }
        @{ test = 'no-openai'; expected = 'allow_implicit_invocation: false' }
        @{ test = 'approved exception missing'; expected = 'matches no skill folder' }
        @{ test = 'approved exception approved-explicit'; expected = 'remove its entry' }
        @{ test = 'approved exception approved-no-reason'; expected = 'without the reason' }
    ) {
        $result = $script:invocation | Where-Object Name -EQ $test

        $result.Result | Should -Be 'Failed'
        $result.Message | Should -BeLike "*$expected*"
    }
}
