BeforeAll {
    $script:evals = Join-Path $PSScriptRoot '..' '..' 'tools' 'evals.ps1'

    function Invoke-Evals([string[]] $Name, [switch] $InProgress) {
        $names = ($Name | ForEach-Object { "'$_'" }) -join ','
        $flag = $InProgress ? '-InProgress' : ''
        $output = & pwsh -NoProfile -Command "& '$script:evals' $flag -Name $names; exit `$LASTEXITCODE" 2>&1 | Out-String
        [pscustomobject] @{ ExitCode = $LASTEXITCODE; Output = $output }
    }
}

Describe 'evals.ps1 -Name' {
    It 'exits 1 and lists a name that matches no eval' {
        $result = Invoke-Evals 'no-such-eval'

        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'no-such-eval'
    }

    It 'exits 1 without running any eval when known and unknown names are mixed, listing only the unknown' {
        $result = Invoke-Evals 'notify', 'no-such-eval'

        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'no-such-eval'
        $result.Output | Should -Not -Match 'notify'
        $result.Output | Should -Not -Match '==='
    }
}

Describe 'evals.ps1 -InProgress' {
    It 'does not know an in-progress eval without -InProgress' {
        $result = Invoke-Evals 'exec-synt-workflow', 'no-such-eval'

        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'exec-synt-workflow'
    }

    It 'knows only in-progress evals with -InProgress' {
        $result = Invoke-Evals 'exec-synt-workflow', 'notify' -InProgress

        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'Unknown evals: notify'
        $result.Output | Should -Not -Match 'Unknown evals:.*exec-synt-workflow'
        $result.Output | Should -Not -Match '==='
    }
}
