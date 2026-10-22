param(
    [string[]] $SkillsRoot = @(
        Join-Path $PSScriptRoot '..' '..' '..' 'skills'
        Join-Path $PSScriptRoot '..' '..' '..' 'in-progress' 'skills'
    ),
    [string] $ScriptTestsRoot = (Join-Path $PSScriptRoot '..' '..' '..' 'tests' 'script-tests')
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

    function Get-SkillPath([string] $Dir, [IO.FileInfo] $File) {
        [IO.Path]::GetRelativePath($Dir, $File.FullName) -replace '\\', '/'
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
        $chapters = @{ 'Initialization' = @(); 'Steps' = @() }
        $chapter = $null
        foreach ($line in Get-ProseLines $path) {
            if ($line -match '^#{1,2} ') {
                $chapter = if ($line -match '^## (Initialization|Steps)\s*$') { $Matches[1] }
                continue
            }
            if ($chapter -and $line -match '^### ') { $chapters[$chapter] += $line }
        }

        foreach ($name in $chapters.Keys) {
            $steps = $chapters[$name]
            for ($i = 0; $i -lt $steps.Count; $i++) {
                $steps[$i] | Should -Match "^### $($i + 1)\. \S" -Because (
                    "the chapters under `"## $name`" are numbered from 1 as `"### N. <action>`" " +
                    '(see docs/guidelines/skills.md#workflow-skills)')
            }
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
            "every script is covered by Pester tests in tests/script-tests/$name/ that name it " +
            "(see docs/guidelines/skills.md#scripts); add tests for: $($untested -join ', ')")
    }
}

Describe 'Skill file mentions' {
    It '<name>' -ForEach $skills {
        $text = Get-Content -LiteralPath $path -Raw
        $files = Get-ChildItem -LiteralPath $dir -File -Recurse
        $unmentioned = @(
            Get-SkillFiles $dir 'references' |
                Where-Object { -not $text.Contains((Get-SkillPath $dir $_)) }
            # Scripts build an asset's path from its parts, so the asset's name counts as its mention.
            Get-SkillFiles $dir 'assets' |
                Where-Object {
                    $asset = $_
                    -not ($files | Where-Object { $_.FullName -ne $asset.FullName -and "$(Get-Content -LiteralPath $_.FullName -Raw)".Contains($asset.Name) })
                }
        ) | Where-Object { -not $_.Name.StartsWith('.') } | ForEach-Object { Get-SkillPath $dir $_ }

        $unmentioned | Should -BeNullOrEmpty -Because (
            'SKILL.md mentions every file in references/ by its path in the skill folder, e.g. references/TERMS.md, ' +
            'and the instruction or script that uses a file in assets/ mentions it ' +
            "(see docs/guidelines/skills.md#skill-folder); mention: $($unmentioned -join ', ')")
    }
}
