BeforeAll {
    $script:checkPrerequisites = Join-Path $PSScriptRoot '..' '..' '..' 'skills' 'win-app-spy' 'scripts' 'check-prerequisites.ps1'

    # Puts a fake `dotnet` on a PATH of its own; omitted outputs make the fake fail for that call.
    function Set-FakeDotnet {
        param([string[]] $Sdks, [string] $ScriptVersion)
        $bin = Join-Path $TestDrive ([guid]::NewGuid())
        New-Item -ItemType Directory -Path $bin | Out-Null
        $lines = @('@echo off')
        if ($PSBoundParameters.ContainsKey('Sdks')) {
            $lines += 'if "%1"=="--list-sdks" ('
            $lines += $Sdks | ForEach-Object { "  echo $_ [C:\Program Files\dotnet\sdk]" }
            $lines += '  exit /b 0', ')'
        }
        if ($ScriptVersion) { $lines += "if `"%1 %2`"==`"script --version`" ( echo $ScriptVersion& exit /b 0 )" }
        $lines += 'echo Could not execute because the specified command or file was not found. 1>&2', 'exit /b 1'
        Set-Content -LiteralPath (Join-Path $bin 'dotnet.cmd') -Value $lines -Encoding ascii
        $env:PATH = $bin
    }

    # A child process, so the test sees what the script writes to the process's stderr.
    function Invoke-CheckPrerequisites {
        $output = & (Join-Path $PSHOME 'pwsh') -NoProfile -File $script:checkPrerequisites 2>&1 | Out-String
        [pscustomobject] @{ ExitCode = $LASTEXITCODE; Output = $output }
    }
}

Describe 'check-prerequisites.ps1' {
    BeforeEach { $script:originalPath = $env:PATH }
    AfterEach { $env:PATH = $script:originalPath }

    It 'exits 0 and prints the newest .NET SDK and the dotnet-script version' {
        Set-FakeDotnet -Sdks '8.0.426', '10.0.303' -ScriptVersion '2.0.1'

        $result = Invoke-CheckPrerequisites

        $result.ExitCode | Should -Be 0
        $result.Output | Should -BeLike '*.NET SDK: 10.0.303*'
        $result.Output | Should -BeLike '*dotnet-script: 2.0.1*'
    }

    It 'exits 2 and prints how to install <missing> when <case>' -ForEach @(
        @{ case = 'dotnet is not on the PATH'; missing = 'the .NET SDK and dotnet-script'; fake = $null; sdk = $true; tool = $true }
        @{ case = 'only the .NET runtime is installed'; missing = 'the .NET SDK'; fake = @{ Sdks = @(); ScriptVersion = '2.0.1' }; sdk = $true; tool = $false }
        @{ case = 'dotnet-script is not installed'; missing = 'dotnet-script'; fake = @{ Sdks = @('10.0.303') }; sdk = $false; tool = $true }
    ) {
        if ($fake) { Set-FakeDotnet @fake } else { $env:PATH = Join-Path $TestDrive 'empty' }

        $result = Invoke-CheckPrerequisites

        $result.ExitCode | Should -Be 2
        ($result.Output -like '*https://dotnet.microsoft.com/download*') | Should -Be $sdk
        ($result.Output -like '*dotnet tool install -g dotnet-script*') | Should -Be $tool
    }

    It 'exits 0 with the real dotnet and dotnet-script' -Skip:(-not (Get-Command dotnet-script -ErrorAction SilentlyContinue)) {
        $result = Invoke-CheckPrerequisites

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match '\.NET SDK: \d+\.\d+\.\d+'
        $result.Output | Should -Match 'dotnet-script: \d+\.\d+\.\d+'
    }
}
