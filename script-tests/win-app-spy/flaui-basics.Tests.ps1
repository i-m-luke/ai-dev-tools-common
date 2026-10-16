# Covers the sample ad hoc script in references/flaui-basics.md: run as the reference tells, beside a
# copy of the scripts, it loads core.csx and prints the standard envelope. Its run against Notepad
# is verified by hand, since parallel runs share one desktop.
BeforeDiscovery {
    $script:noDotnetScript = -not (Get-Command dotnet-script -ErrorAction SilentlyContinue)
}

BeforeAll {
    $skillFolder = Join-Path $PSScriptRoot '..' '..' 'skills' 'win-app-spy'
    $script:workingFolder = Join-Path $TestDrive 'working-folder'
    New-Item -ItemType Directory -Path $script:workingFolder | Out-Null
    Copy-Item -Path (Join-Path $skillFolder 'scripts' '*') -Destination $script:workingFolder -Recurse

    $reference = Get-Content -LiteralPath (Join-Path $skillFolder 'references' 'flaui-basics.md') -Raw
    $match = [regex]::Match($reference, '(?s)## Sample script.*?```csharp\r?\n(.*?)```')
    $script:sampleScript = Join-Path $script:workingFolder 'list-buttons.csx'
    if ($match.Success) { Set-Content -LiteralPath $script:sampleScript -Value $match.Groups[1].Value -Encoding utf8 }
}

Describe 'flaui-basics.md sample script' {
    It 'is a csharp block under "Sample script"' {
        $script:sampleScript | Should -Exist
    }

    It 'loads the core and answers a missing active app with the standard error envelope' -Skip:$noDotnetScript {
        Push-Location $script:workingFolder
        try { $stdout = & dotnet script $script:sampleScript 2>$null | Out-String }
        finally { Pop-Location }

        $LASTEXITCODE | Should -Be 1
        $json = $stdout | ConvertFrom-Json -AsHashtable
        $json.command | Should -Be 'list-buttons'
        $json.error.code | Should -Be 'APP_NOT_FOUND'
        $json.Keys | Should -Not -Contain 'data'
    }
}
