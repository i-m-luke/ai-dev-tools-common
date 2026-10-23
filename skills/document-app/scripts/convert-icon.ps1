<#
.SYNOPSIS
Converts an application icon into a PNG image for inline use in an app document.

.DESCRIPTION
Reads an image from the application's resources (ICO, PNG, BMP, GIF, JPEG or TIFF), scales it to
the given height with its aspect ratio kept, and saves it as PNG, creating the destination folder
when missing. From an ICO file it takes the frame closest to the given height. Runs on Windows only.

.PARAMETER SourcePath
The image file to convert.

.PARAMETER DestinationPath
The PNG file to write, e.g. `docs/img/save-icon.png`.

.PARAMETER Height
The height of the PNG in pixels, 16 to 24; 20 when omitted.

.OUTPUTS
::result::{"path":"<the PNG file>","width":<pixels>,"height":<pixels>}

.NOTES
Exit codes:
- 0: the PNG file is written.
- 20: the source file does not exist.
- 21: the source file is not an image this script can read, e.g. a vector image.

Stderr: the reason of the failure.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $SourcePath,
    [Parameter(Mandatory)] [string] $DestinationPath,
    [ValidateRange(16, 24)] [int] $Height = 20
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.Drawing

$source = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($SourcePath)
$destination = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($DestinationPath)
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    [Console]::Error.WriteLine("The source image $source does not exist.")
    exit 20
}

try {
    $image = if ([IO.Path]::GetExtension($source) -eq '.ico') {
        ([Drawing.Icon]::new($source, $Height, $Height)).ToBitmap()
    } else {
        [Drawing.Image]::FromFile($source)
    }
} catch {
    [Console]::Error.WriteLine("The source $source is not a readable raster image: $($_.Exception.Message)")
    exit 21
}

try {
    $width = [Math]::Max(1, [int] [Math]::Round($image.Width * $Height / $image.Height))
    $bitmap = [Drawing.Bitmap]::new($width, $Height)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.DrawImage($image, 0, 0, $width, $Height)
        } finally {
            $graphics.Dispose()
        }
        [void] [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
        $bitmap.Save($destination, [Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $bitmap.Dispose()
    }
} finally {
    $image.Dispose()
}

Write-Host "Saved $source as $destination"
[Console]::Out.WriteLine('::result::' + (@{ path = $destination; width = $width; height = $Height } | ConvertTo-Json -Compress))
