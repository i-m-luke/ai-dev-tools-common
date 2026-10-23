<#
.SYNOPSIS
Gives every heading of an app document an anchor and rebuilds its table of contents.

.DESCRIPTION
Reads the Markdown document, adds a `{#anchor}` to every heading from level 2 down that lacks one,
rewrites the list between the `<!--TOC-->` and `<!--/TOC-->` markers to mirror the heading
hierarchy, and lists the in-document links whose anchor no heading carries.

A generated anchor is the heading text in ASCII (lowercase, hyphenated, diacritics stripped),
made unique with a numeric suffix. An existing anchor is kept as it is. Headings above the end
marker (the title and the contents heading) and headings in fenced code blocks are skipped.

.PARAMETER Path
The Markdown document to update.

.OUTPUTS
::result::{"path":"<the document>","headings":<number of headings in the TOC>,"addedAnchors":["<anchor>"],"brokenLinks":["<anchor>"]}

.NOTES
Exit codes:
- 0: the document is updated.
- 20: the document does not exist.
- 21: the document lacks the `<!--TOC-->` or `<!--/TOC-->` marker, or holds them in the wrong order.

Stderr: the reason of the failure.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Path
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

function ConvertTo-Anchor([string] $Text) {
    $plain = $Text -replace '\[([^\]]*)\]\([^)]*\)', '$1' -replace '[`*_]', ''
    $decomposed = $plain.Normalize([Text.NormalizationForm]::FormD)
    $kept = $decomposed.ToCharArray() | Where-Object {
        [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne [Globalization.UnicodeCategory]::NonSpacingMark
    }
    $anchor = (-join $kept).ToLowerInvariant() -replace '[^a-z0-9]+', '-' -replace '^-+|-+$', ''
    if ($anchor) { $anchor } else { 'section' }
}

function Test-Fence([string] $Line) { $Line -match '^\s*(```|~~~)' }

$fullPath = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path)
if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
    [Console]::Error.WriteLine("The document $fullPath does not exist.")
    exit 20
}

$text = [IO.File]::ReadAllText($fullPath, [Text.Encoding]::UTF8)
$newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
$endsWithNewline = $text.EndsWith("`n")
$lines = [Collections.Generic.List[string]]::new([string[]] ($text -split '\r?\n'))
if ($endsWithNewline) { $lines.RemoveAt($lines.Count - 1) }

$tocStart = $lines.IndexOf('<!--TOC-->')
$tocEnd = $lines.IndexOf('<!--/TOC-->')
if ($tocStart -lt 0 -or $tocEnd -lt $tocStart) {
    [Console]::Error.WriteLine("The document $fullPath needs a <!--TOC--> line followed by a <!--/TOC--> line.")
    exit 21
}

$headingPattern = '^(#{2,6})\s+(.*?)\s*(?:\{#([^}\s]+)\})?\s*$'
$headings = [Collections.Generic.List[object]]::new()
$inFence = $false
for ($i = $tocEnd + 1; $i -lt $lines.Count; $i++) {
    if (Test-Fence $lines[$i]) { $inFence = -not $inFence; continue }
    if (-not $inFence -and $lines[$i] -match $headingPattern) {
        $headings.Add([pscustomobject] @{ Index = $i; Level = $Matches[1].Length; Text = $Matches[2]; Anchor = $Matches[3] })
    }
}

$anchors = [Collections.Generic.HashSet[string]]::new()
foreach ($heading in $headings) { if ($heading.Anchor) { [void] $anchors.Add($heading.Anchor) } }

$addedAnchors = [Collections.Generic.List[string]]::new()
foreach ($heading in $headings) {
    if ($heading.Anchor) { continue }
    $base = ConvertTo-Anchor $heading.Text
    $anchor = $base
    for ($n = 2; $anchors.Contains($anchor); $n++) { $anchor = "$base-$n" }
    [void] $anchors.Add($anchor)
    $heading.Anchor = $anchor
    $lines[$heading.Index] = ('#' * $heading.Level) + " $($heading.Text) {#$anchor}"
    $addedAnchors.Add($anchor)
}

$brokenLinks = [Collections.Generic.List[string]]::new()
$inFence = $false
for ($i = $tocEnd + 1; $i -lt $lines.Count; $i++) {
    if (Test-Fence $lines[$i]) { $inFence = -not $inFence; continue }
    if ($inFence) { continue }
    foreach ($link in [regex]::Matches($lines[$i], '\]\(#([^)\s]+)\)')) {
        $target = $link.Groups[1].Value
        if (-not $anchors.Contains($target) -and -not $brokenLinks.Contains($target)) { $brokenLinks.Add($target) }
    }
}

$toc = [Collections.Generic.List[string]]::new()
$toc.Add('')
foreach ($heading in $headings) {
    $toc.Add(('  ' * ($heading.Level - 2)) + "- [$($heading.Text)](#$($heading.Anchor))")
}
$toc.Add('')
$lines.RemoveRange($tocStart + 1, $tocEnd - $tocStart - 1)
$lines.InsertRange($tocStart + 1, $toc)

$output = ($lines -join $newline) + $(if ($endsWithNewline) { $newline } else { '' })
[IO.File]::WriteAllText($fullPath, $output, [Text.UTF8Encoding]::new($false))
Write-Host "Updated the table of contents of $fullPath"

$result = @{
    path         = $fullPath
    headings     = $headings.Count
    addedAnchors = $addedAnchors.ToArray()
    brokenLinks  = $brokenLinks.ToArray()
}
[Console]::Out.WriteLine('::result::' + ($result | ConvertTo-Json -Compress -Depth 10))
