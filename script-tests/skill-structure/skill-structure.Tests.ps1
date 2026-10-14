param(
    [string[]] $SkillsRoot = @(
        Join-Path $PSScriptRoot '..' '..' 'skills'
        Join-Path $PSScriptRoot '..' '..' 'in-progress' 'skills'
    ),
    [string] $ScriptTestsRoot = (Join-Path $PSScriptRoot '..')
)

BeforeDiscovery {
    $skills = Get-ChildItem -LiteralPath ($SkillsRoot | Where-Object { Test-Path -LiteralPath $_ }) -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') } |
        ForEach-Object {
            @{ name = $_.Name; dir = $_.FullName; path = Join-Path $_.FullName 'SKILL.md'; scriptTests = Join-Path $ScriptTestsRoot $_.Name }
        }
}

BeforeAll {
    # Lines of a Markdown file outside fenced code blocks, where headings are only illustrations.
    function Get-ProseLines([string] $Path) {
        $inFence = $false
        foreach ($line in Get-Content -LiteralPath $Path) {
            if ($line -match '^\s*(```|~~~)') { $inFence = -not $inFence; continue }
            if (-not $inFence) { $line }
        }
    }

    function Get-SkillFiles([string] $Dir, [string[]] $Folders) {
        foreach ($folder in $Folders) {
            $path = Join-Path $Dir $folder
            if (Test-Path -LiteralPath $path -PathType Container) { Get-ChildItem -LiteralPath $path -File -Recurse }
        }
    }
}

Describe 'Skill folder layout' {
    It '<name>' -ForEach $skills {
        $unknown = Get-ChildItem -LiteralPath $dir -Force |
            Where-Object Name -NotIn 'SKILL.md', 'agents', 'scripts', 'assets', 'references' |
            ForEach-Object Name

        $unknown | Should -BeNullOrEmpty -Because (
            'a skill folder holds SKILL.md, agents/, scripts/, assets/ and references/ ' +
            "(see docs/guidelines/skills.md#skill-folder); move these elsewhere: $($unknown -join ', ')")
    }
}

Describe 'Skill steps' {
    It '<name>' -ForEach $skills {
        $inSteps = $false
        $steps = @(foreach ($line in Get-ProseLines $path) {
                if ($line -match '^#{1,2} ') { $inSteps = $line -match '^## Steps\s*$'; continue }
                if ($inSteps -and $line -match '^### ') { $line }
            })

        for ($i = 0; $i -lt $steps.Count; $i++) {
            $steps[$i] | Should -Match "^### $($i + 1)\. \S" -Because (
                'the chapters under "## Steps" are numbered from 1 as "### N. <action>" ' +
                '(see docs/guidelines/skills.md#workflow-skills)')
        }
    }
}

Describe 'Skill script tests' {
    It '<name>' -ForEach $skills {
        $scripts = Get-SkillFiles $dir 'scripts'
        $tests = if (Test-Path -LiteralPath $scriptTests) { Get-ChildItem -LiteralPath $scriptTests -Filter '*.Tests.ps1' -File }
        $testsText = ($tests | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
        $untested = $scripts | Where-Object { -not $testsText.Contains($_.Name) } | ForEach-Object Name

        $untested | Should -BeNullOrEmpty -Because (
            "every script is covered by Pester tests in script-tests/$name/ that name it " +
            "(see docs/guidelines/skills.md#scripts); add tests for: $($untested -join ', ')")
    }
}

Describe 'Skill file mentions' {
    It '<name>' -ForEach $skills {
        $text = Get-Content -LiteralPath $path -Raw
        $unmentioned = Get-SkillFiles $dir 'assets', 'references' |
            ForEach-Object { [IO.Path]::GetRelativePath($dir, $_.FullName) -replace '\\', '/' } |
            Where-Object { -not $text.Contains($_) }

        $unmentioned | Should -BeNullOrEmpty -Because (
            'SKILL.md mentions every file in assets/ and references/ by its path in the skill folder, ' +
            "e.g. references/TERMS.md (see docs/guidelines/skills.md#skill-folder); mention: $($unmentioned -join ', ')")
    }
}
