param([string] $SkillsRoot = (Join-Path $PSScriptRoot '..' '..' 'skills'))

BeforeDiscovery {
    $skills = Get-ChildItem -LiteralPath $SkillsRoot -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') } |
        ForEach-Object { @{ name = $_.Name; path = Join-Path $_.FullName 'SKILL.md' } }
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
}

Describe 'Skill frontmatter' {
    It '<name>' -ForEach $skills {
        $frontmatter = Get-Frontmatter $path

        $frontmatter.name | Should -Be $name -Because 'name must match the skill folder'
        $frontmatter.description | Should -BeOfType [string] -Because 'description is required'
        $frontmatter.description | Should -Not -BeNullOrEmpty -Because 'description is required'
        $frontmatter.description | Should -BeLikeExactly 'Use when *' -Because 'a skill description starts with "Use when" (see docs/guidelines/index.md)'
    }
}
