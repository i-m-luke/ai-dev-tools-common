# Covers the sample ad hoc script in references/flaui-basics.md: saved in a working folder and run as
# the reference tells, it loads the core from the skill's folder and answers like spy.csx. Its run
# against Notepad is verified by hand, since parallel runs share one desktop.
BeforeDiscovery {
    $script:noDotnetScript = -not (Get-Command dotnet-script -ErrorAction SilentlyContinue)
}

BeforeAll {
    . (Join-Path $PSScriptRoot 'spy-test-helpers.ps1')
    Initialize-SpyWorkingFolder
    $skillFolder = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' 'skills' 'win-app-spy')).Path

    $reference = Get-Content -LiteralPath (Join-Path $skillFolder 'references' 'flaui-basics.md') -Raw
    $match = [regex]::Match($reference, '(?s)## Sample script.*?```csharp\r?\n(.*?)```')
    $script:sampleScript = Join-Path $script:spyWorkingFolder 'list-buttons.csx'
    if ($match.Success) {
        $source = $match.Groups[1].Value.Replace("<this skill's folder>", ($skillFolder -replace '\\', '/'))
        Set-Content -LiteralPath $script:sampleScript -Value $source -Encoding utf8
    }
}

AfterAll { Restore-SpyConsoleEncoding }

Describe 'flaui-basics.md sample script' {
    It 'is a csharp block under "Sample script"' {
        $script:sampleScript | Should -Exist
    }

    It 'loads the core and answers a missing active app with APP_NOT_FOUND on stderr and exit 20' -Skip:$noDotnetScript {
        $request = Join-Path $script:spyWorkingFolder 'req.json'
        Set-Content -LiteralPath $request -Value '{}' -Encoding utf8

        $result = Invoke-SpyScript -Script $script:sampleScript -Arguments '--request-path', $request

        $result.ExitCode | Should -Be 20 -Because $result.Raw
        $result.ResultLines | Should -Be 0
        $result.Json.error.code | Should -Be 'APP_NOT_FOUND'
    }
}
