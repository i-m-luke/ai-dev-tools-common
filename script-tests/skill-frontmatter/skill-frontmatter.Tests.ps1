param(
    [string[]] $SkillsRoot = @(
        Join-Path $PSScriptRoot '..' '..' 'skills'
        Join-Path $PSScriptRoot '..' '..' 'in-progress' 'skills'
    ),
    [string] $ImplicitSkillsPath = (Join-Path $PSScriptRoot 'implicit-skills.yaml')
)

BeforeDiscovery {
    Import-Module powershell-yaml

    $implicitSkills = if (Test-Path -LiteralPath $ImplicitSkillsPath) { Get-Content -LiteralPath $ImplicitSkillsPath -Raw | ConvertFrom-Yaml }
    $skillDirs = Get-ChildItem -LiteralPath ($SkillsRoot | Where-Object { Test-Path -LiteralPath $_ }) -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') }

    $skills = $skillDirs | ForEach-Object {
        @{ name = $_.Name; dir = $_.FullName; path = Join-Path $_.FullName 'SKILL.md'; approved = $null -ne $implicitSkills -and $implicitSkills.Contains($_.Name) }
    }
    $approvedSkills = @($implicitSkills.Keys) | Where-Object { $_ } | ForEach-Object {
        $name = $_
        $dir = ($skillDirs | Where-Object Name -EQ $name | Select-Object -First 1).FullName
        @{ name = $name; reason = $implicitSkills[$name]; dir = $dir }
    }
}

BeforeAll {
    Import-Module powershell-yaml

    function Get-Frontmatter([string] $Path) {
        $match = [regex]::Match((Get-Content -LiteralPath $Path -Raw), '\A---\r?\n(.*?)\r?\n---\r?(\n|\z)', 'Singleline')
        if (-not $match.Success) { throw 'SKILL.md has no frontmatter between leading --- delimiters.' }
        try {
            $match.Groups[1].Value | ConvertFrom-Yaml
        }
        catch {
            throw "Frontmatter is not valid YAML: $($_.Exception.GetBaseException().Message)"
        }
    }

    # Explicit when run by other skills ("Use ONLY when"), or with model invocation off in both SKILL.md and agents/openai.yaml.
    function Get-MissingExplicitSettings([string] $Dir) {
        $frontmatter = Get-Frontmatter (Join-Path $Dir 'SKILL.md')
        if ($frontmatter.description -cmatch '^Use ONLY when ') { return }
        if ($frontmatter['disable-model-invocation'] -ne $true) { '`disable-model-invocation: true` in SKILL.md' }
        $openai = Join-Path $Dir 'agents' 'openai.yaml'
        $policy = (Test-Path -LiteralPath $openai) ? (Get-Content -LiteralPath $openai -Raw | ConvertFrom-Yaml).policy : $null
        if ($null -eq $policy -or $policy.allow_implicit_invocation -ne $false) { '`policy.allow_implicit_invocation: false` in agents/openai.yaml' }
    }
}

Describe 'Skill frontmatter' {
    It '<name>' -ForEach $skills {
        $frontmatter = Get-Frontmatter $path

        $frontmatter.name | Should -Be $name -Because 'name must match the skill folder'
        $frontmatter.description | Should -BeOfType [string] -Because 'description is required'
        $frontmatter.description | Should -Not -BeNullOrEmpty -Because 'description is required'
        $frontmatter.description | Should -MatchExactly '^Use (ONLY )?when ' -Because 'a skill description starts with "Use when" or "Use ONLY when" (see docs/guidelines/skills.md)'
    }
}

Describe 'Skill invocation' {
    It '<name>' -ForEach $skills {
        if ($approved) { return }

        $missing = @(Get-MissingExplicitSettings $dir)

        if ($missing.Count -gt 0 -and (Get-Frontmatter $path)['disable-model-invocation'] -eq $true) {
            $missing.Count | Should -Be 0 -Because (
                "skill '$name' turns model invocation off in SKILL.md (``disable-model-invocation: true``), but " +
                'agents/openai.yaml conflicts with it: set `policy.allow_implicit_invocation: false` there so both agree ' +
                '(docs/guidelines/skills.md#invocation)')
        }

        $missing.Count | Should -Be 0 -Because (
            "skill '$name' is not explicit, it lacks $($missing -join ' and '). Skills are explicit by default " +
            '(docs/guidelines/skills.md#invocation): set both `disable-model-invocation: true` in SKILL.md and ' +
            '`policy.allow_implicit_invocation: false` in agents/openai.yaml, or start the description with ' +
            '"Use ONLY when" if other skills run it. If it is a convention skill that must load implicitly, add it ' +
            'with a reason to script-tests/skill-frontmatter/implicit-skills.yaml - the list of approved exceptions')
    }

    It 'approved exception <name>' -ForEach $approvedSkills {
        $dir | Should -Not -BeNullOrEmpty -Because "implicit-skills.yaml lists '$name', which matches no skill folder; remove the entry"
        $reason | Should -Not -BeNullOrEmpty -Because "implicit-skills.yaml lists '$name' without the reason it stays implicit"
        @(Get-MissingExplicitSettings $dir).Count | Should -BeGreaterThan 0 -Because "skill '$name' is explicit; remove its entry from implicit-skills.yaml"
    }
}
