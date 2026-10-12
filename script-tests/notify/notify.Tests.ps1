BeforeAll {
    $script:notify = Join-Path $PSScriptRoot '..' '..' 'skills' 'notify' 'scripts' 'notify.ps1'

    function New-SecretsFile([string] $Folder, [string] $Content) {
        New-Item -ItemType Directory -Force -Path $Folder | Out-Null
        $path = Join-Path $Folder 'agents.secrets.yaml'
        Set-Content -LiteralPath $path -Value $Content -Encoding utf8
        $path
    }

    function Invoke-Notify {
        param([string] $Msg = 'hello', [string] $SecretsPath)
        $params = @{ Msg = $Msg }
        if ($SecretsPath) { $params.SecretsPath = $SecretsPath }
        & $script:notify @params 2>$null | Out-Null
        $LASTEXITCODE
    }

    $script:validSecrets = "notify:`n  token: `"123:abc`"`n  chatId: `"42`""
}

Describe 'notify.ps1' {
    BeforeEach {
        $script:originalUserProfile = $env:USERPROFILE
        $script:originalHome = $env:HOME
        $root = Join-Path $TestDrive ([guid]::NewGuid())
        $env:USERPROFILE = Join-Path $root 'home'
        $env:HOME = $env:USERPROFILE
        $script:workDir = Join-Path $root 'work'
        New-Item -ItemType Directory -Path $script:workDir | Out-Null
        Push-Location $script:workDir
        Mock Invoke-RestMethod { [pscustomobject] @{ ok = $true } }
    }

    AfterEach {
        Pop-Location
        $env:USERPROFILE = $script:originalUserProfile
        $env:HOME = $script:originalHome
    }

    Context 'Sending' {
        It 'sends the message to the configured chat and exits 0' {
            $path = New-SecretsFile $script:workDir $script:validSecrets

            Invoke-Notify -Msg 'Plan ready' -SecretsPath $path | Should -Be 0

            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $sent = [Text.Encoding]::UTF8.GetString($Body) | ConvertFrom-Json
                $Uri -eq 'https://api.telegram.org/bot123:abc/sendMessage' -and
                $sent.chat_id -eq '42' -and $sent.text -eq 'Plan ready'
            }
        }

        It 'truncates a message longer than 4096 characters' {
            $path = New-SecretsFile $script:workDir $script:validSecrets

            Invoke-Notify -Msg ('x' * 5000) -SecretsPath $path | Should -Be 0

            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $text = ([Text.Encoding]::UTF8.GetString($Body) | ConvertFrom-Json).text
                $text.Length -eq 4096 -and $text.EndsWith([string] [char] 0x2026)
            }
        }

        It 'reads unquoted values, comments and other sections' {
            $content = "# secrets`nother:`n  token: wrong`nnotify:`n  token: 123:abc # bot`n  chatId: -42`nlast:`n  chatId: wrong"
            $path = New-SecretsFile $script:workDir $content

            Invoke-Notify -SecretsPath $path | Should -Be 0

            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $sent = [Text.Encoding]::UTF8.GetString($Body) | ConvertFrom-Json
                $Uri -eq 'https://api.telegram.org/bot123:abc/sendMessage' -and $sent.chat_id -eq '-42'
            }
        }
    }

    Context 'Config file lookup' {
        It 'uses the git repository root' {
            git init --quiet $script:workDir
            New-SecretsFile $script:workDir $script:validSecrets | Out-Null
            $subDir = New-Item -ItemType Directory -Path (Join-Path $script:workDir 'sub')
            Set-Location $subDir

            Invoke-Notify | Should -Be 0
        }

        It 'falls back to ~/.agents outside a git repository' {
            New-SecretsFile (Join-Path $env:USERPROFILE '.agents') $script:validSecrets | Out-Null

            Invoke-Notify | Should -Be 0
        }

        It 'prefers the git repository root over ~/.agents' {
            git init --quiet $script:workDir
            New-SecretsFile $script:workDir "notify:`n  token: repo`n  chatId: 1" | Out-Null
            New-SecretsFile (Join-Path $env:USERPROFILE '.agents') "notify:`n  token: home`n  chatId: 1" | Out-Null

            Invoke-Notify | Should -Be 0

            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Uri -eq 'https://api.telegram.org/botrepo/sendMessage'
            }
        }

        It 'exits 1 when no config file is found' {
            Invoke-Notify | Should -Be 1
            Should -Invoke Invoke-RestMethod -Times 0
        }

        It 'exits 1 when -SecretsPath does not exist, without falling back' {
            New-SecretsFile (Join-Path $env:USERPROFILE '.agents') $script:validSecrets | Out-Null

            Invoke-Notify -SecretsPath (Join-Path $script:workDir 'missing.yaml') | Should -Be 1
        }
    }

    Context 'Invalid config file' {
        It 'exits 2 when <case>' -ForEach @(
            @{ case = 'the notify section is missing'; content = "other:`n  token: x`n  chatId: 1" }
            @{ case = 'the token is empty'; content = "notify:`n  token: `"`"`n  chatId: 1" }
            @{ case = 'the chatId is missing'; content = "notify:`n  token: x" }
            @{ case = 'the file is empty'; content = '' }
        ) {
            $path = New-SecretsFile $script:workDir $content

            Invoke-Notify -SecretsPath $path | Should -Be 2
            Should -Invoke Invoke-RestMethod -Times 0
        }
    }

    Context 'Telegram errors' {
        It 'exits 3 when the request fails' {
            Mock Invoke-RestMethod { throw 'network down' }
            $path = New-SecretsFile $script:workDir $script:validSecrets

            Invoke-Notify -SecretsPath $path | Should -Be 3
        }

        It 'exits 3 when Telegram rejects the message' {
            Mock Invoke-RestMethod { [pscustomobject] @{ ok = $false; description = 'Bad Request' } }
            $path = New-SecretsFile $script:workDir $script:validSecrets

            Invoke-Notify -SecretsPath $path | Should -Be 3
        }
    }
}
