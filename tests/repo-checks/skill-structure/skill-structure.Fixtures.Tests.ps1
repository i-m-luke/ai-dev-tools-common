BeforeAll {
    $script:structureTests = Join-Path $PSScriptRoot 'skill-structure.Tests.ps1'

    function New-Skill([string] $Folder, [string] $Body, [hashtable] $Files = @{}) {
        $dir = New-Item -ItemType Directory -Force -Path (Join-Path $script:skillsRoot $Folder)
        Set-Content -LiteralPath (Join-Path $dir 'SKILL.md') -Value "---`nname: $Folder`ndescription: Use when testing.`n---`n`n$Body" -Encoding utf8
        foreach ($file in $Files.Keys) {
            $path = Join-Path $dir $file
            New-Item -ItemType Directory -Force -Path (Split-Path $path -Parent) | Out-Null
            Set-Content -LiteralPath $path -Value $Files[$file] -Encoding utf8
        }
    }

    # A separate process keeps the nested Pester run from interfering with this one.
    function Invoke-StructureTests([string] $SkillsRoot, [string] $ScriptTestsRoot) {
        # Without its file, Pester would fall back to running the current folder, this file included.
        if (-not (Test-Path -LiteralPath $script:structureTests)) { throw "Not found: $script:structureTests" }
        pwsh -NoProfile -Command {
            param($TestsPath, $SkillsRoot, $ScriptTestsRoot)
            $container = New-PesterContainer -Path $TestsPath -Data @{ SkillsRoot = $SkillsRoot; ScriptTestsRoot = $ScriptTestsRoot }
            $result = Invoke-Pester -Container $container -PassThru -Output None
            $result.Tests | ForEach-Object {
                [pscustomobject] @{
                    Test    = "$($_.Block.Name) / $($_.ExpandedName)"
                    Result  = "$($_.Result)"
                    Message = ($_.ErrorRecord | ForEach-Object { $_.Exception.Message }) -join "`n"
                }
            }
        } -args $script:structureTests, $SkillsRoot, $ScriptTestsRoot
    }

    $script:skillsRoot = Join-Path $TestDrive 'skills'
    $scriptTestsRoot = Join-Path $TestDrive 'script-tests'

    New-Skill 'valid' "## Initialization`n`n### 1. Check`n`n## Steps`n`n### 1. Run`n`nSee ``references/guide.md`` and ``assets/page.html``.`n`n### 2. Close`n`n## Notes" @{
        'agents/openai.yaml'        = 'interface: {}'
        'scripts/run.ps1'           = 'exit 0'
        'references/guide.md'       = 'Guide.'
        'assets/page.html'          = '<html></html>'
        # Left unmentioned on purpose: dotfiles configure tools, so the mention check skips them.
        'assets/.markdownlint.json' = '{}'
    }
    New-Item -ItemType Directory -Force -Path (Join-Path $scriptTestsRoot 'valid') | Out-Null
    Set-Content -LiteralPath (Join-Path $scriptTestsRoot 'valid' 'run.Tests.ps1') -Value "# covers run.ps1" -Encoding utf8

    New-Skill 'unknown-entry' 'Body.' @{ 'README.md' = 'Notes.' }
    New-Skill 'unnumbered-step' "## Steps`n`n### Run"
    New-Skill 'skipped-step' "## Steps`n`n### 1. Run`n`n### 3. Close"
    New-Skill 'skipped-init-step' "## Initialization`n`n### 2. Check`n`n## Steps`n`n### 1. Run"
    New-Skill 'prose-steps' "# Syntax`n`n## Steps`n`nOne step per line.`n`n``````text`n### not a step`n```````n`n## Loops`n`n### Loop syntax"
    New-Skill 'untested-script' 'Body.' @{ 'scripts/run.ps1' = 'exit 0' }
    New-Skill 'unmentioned-file' 'Uses a template.' @{ 'assets/page.html' = '<html></html>' }
    New-Skill 'asset-in-reference' 'Read `references/guide.md` when writing.' @{
        'references/guide.md' = 'Fill in `assets/page.html`.'
        'assets/page.html'    = '<html></html>'
    }
    New-Skill 'asset-in-script' 'Run `scripts/run.ps1`.' @{
        'scripts/run.ps1'  = "Get-Content (Join-Path `$PSScriptRoot '..' 'assets' 'page.html')"
        'assets/page.html' = '<html></html>'
    }
    New-Skill 'nested-reference' 'Read `references/guide.md` when writing.' @{
        'references/guide.md'  = 'Read `references/detail.md` for more.'
        'references/detail.md' = 'Detail.'
    }

    $script:results = Invoke-StructureTests $script:skillsRoot $scriptTestsRoot
}

Describe 'skill-structure.Tests.ps1 on fixtures' {
    It 'passes <test>' -ForEach @(
        @{ test = 'Skill folder layout / valid' }
        @{ test = 'Skill steps / valid' }
        @{ test = 'Skill steps / prose-steps' }
        @{ test = 'Skill script tests / valid' }
        @{ test = 'Skill file mentions / valid' }
        @{ test = 'Skill file mentions / asset-in-reference' }
        @{ test = 'Skill file mentions / asset-in-script' }
    ) {
        ($script:results | Where-Object Test -EQ $test).Result | Should -Be 'Passed'
    }

    It 'fails <test> with a message containing "<expected>"' -ForEach @(
        @{ test = 'Skill folder layout / unknown-entry'; expected = 'README.md' }
        @{ test = 'Skill steps / unnumbered-step'; expected = '### N. <action>' }
        @{ test = 'Skill steps / skipped-step'; expected = '### 3. Close' }
        @{ test = 'Skill steps / skipped-init-step'; expected = '## Initialization' }
        @{ test = 'Skill script tests / untested-script'; expected = 'add tests for: run.ps1' }
        @{ test = 'Skill file mentions / unmentioned-file'; expected = 'mention: assets/page.html' }
        @{ test = 'Skill file mentions / nested-reference'; expected = 'mention: references/detail.md' }
    ) {
        $result = $script:results | Where-Object Test -EQ $test

        $result.Result | Should -Be 'Failed'
        $result.Message | Should -BeLike "*$expected*"
    }
}
