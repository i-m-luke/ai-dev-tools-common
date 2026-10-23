BeforeAll {
    Add-Type -AssemblyName System.Drawing
    $script:convertIcon = Join-Path $PSScriptRoot '..' '..' '..' 'skills' 'document-app' 'scripts' 'convert-icon.ps1'

    function New-Png([int] $Width, [int] $Height) {
        $path = Join-Path $TestDrive "$([guid]::NewGuid()).png"
        $bitmap = [Drawing.Bitmap]::new($Width, $Height)
        try { $bitmap.Save($path, [Drawing.Imaging.ImageFormat]::Png) } finally { $bitmap.Dispose() }
        $path
    }

    function New-Ico {
        $path = Join-Path $TestDrive "$([guid]::NewGuid()).ico"
        $bitmap = [Drawing.Bitmap]::new(32, 32)
        $icon = [Drawing.Icon]::FromHandle($bitmap.GetHicon())
        $stream = [IO.File]::Create($path)
        try { $icon.Save($stream) } finally { $stream.Dispose(); $icon.Dispose(); $bitmap.Dispose() }
        $path
    }

    function Invoke-ConvertIcon([string] $SourcePath, [string] $DestinationPath, [int] $Height = 0) {
        $arguments = @('-NoProfile', '-File', $script:convertIcon, '-SourcePath', $SourcePath, '-DestinationPath', $DestinationPath)
        if ($Height) { $arguments += @('-Height', $Height) }
        $stdout = pwsh @arguments 2>$null
        $line = @($stdout | Where-Object { $_ -like '::result::*' })
        [pscustomobject] @{
            ExitCode = $LASTEXITCODE
            Result   = if ($line.Count -eq 1) { $line[0].Substring(10) | ConvertFrom-Json }
        }
    }

    function Get-Size([string] $Path) {
        $image = [Drawing.Image]::FromFile($Path)
        try { "$($image.Width)x$($image.Height)" } finally { $image.Dispose() }
    }
}

Describe 'convert-icon.ps1' {
    It 'scales a PNG to 20 px high by default, keeping the aspect ratio, into a new folder' {
        $destination = Join-Path $TestDrive 'img' 'wide.png'

        $run = Invoke-ConvertIcon (New-Png 64 32) $destination

        $run.ExitCode | Should -Be 0
        $run.Result.path | Should -Be $destination
        Get-Size $destination | Should -Be '40x20'
    }

    It 'takes an ICO frame at the given height' {
        $destination = Join-Path $TestDrive 'icon.png'

        $run = Invoke-ConvertIcon (New-Ico) $destination -Height 16

        $run.ExitCode | Should -Be 0
        Get-Size $destination | Should -Be '16x16'
    }

    It 'exits 20 when the source does not exist' {
        (Invoke-ConvertIcon (Join-Path $TestDrive 'missing.png') (Join-Path $TestDrive 'out.png')).ExitCode | Should -Be 20
    }

    It 'exits 21 when the source is not a raster image' {
        $svg = Join-Path $TestDrive 'icon.svg'
        Set-Content -LiteralPath $svg -Value '<svg xmlns="http://www.w3.org/2000/svg"/>'

        (Invoke-ConvertIcon $svg (Join-Path $TestDrive 'out.png')).ExitCode | Should -Be 21
    }
}
