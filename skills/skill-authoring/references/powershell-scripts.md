# PowerShell scripts

The contract of `references/scripts.md`, worked out in PowerShell.

## Invocation

Run a script as `pwsh -NoProfile -File <this skill's folder>/scripts/<script>.ps1 …`, with `powershell` in place of `pwsh` when pwsh is missing; write it so it runs on Windows PowerShell 5.1 and PowerShell 7+ alike, so the fallback works.
## Help

Write the help as comment-based help at the top of the script; the skill prints it with
`pwsh -NoProfile -Command "Get-Help '<this skill's folder>/scripts/<script>.ps1' -Full"`.

| Outline part | Keyword                                          |
| ------------ | ------------------------------------------------ |
| Purpose      | `.SYNOPSIS`, `.DESCRIPTION`                      |
| Input        | `.PARAMETER` for each parameter                  |
| Result       | `.OUTPUTS`, or `None.` when it returns no result |
| Exit codes   | `.NOTES`                                         |
| Stderr       | `.NOTES`                                         |

## Body

- `$ErrorActionPreference = 'Stop'` turns every error the script does not handle into an unhandled one, which exits with 1.
- Set `[Console]::OutputEncoding` to UTF-8, so non-ASCII text survives stdout.
- Write log lines with `Write-Host`.
- Emit the result with `[Console]::Out.WriteLine('::result::' + (… | ConvertTo-Json -Compress -Depth 10))`.
- End an expected failure with `[Console]::Error.WriteLine('<message>')` and `exit <code>`, the code
  from 2 up.

```powershell
<#
.SYNOPSIS
Exports a repository's open issues to a CSV file.

.DESCRIPTION
Lists the open issues with GitHub CLI and writes their number, title and labels to a CSV file.

.PARAMETER Repository
The repository as `<owner>/<name>`.

.PARAMETER OutputPath
The CSV file to write.

.OUTPUTS
::result::{"path":"<the CSV file>","count":<number of issues>}

.NOTES
Exit codes:
- 0: the CSV file is written.
- 2: the repository does not exist or is not accessible.

Stderr: the reason of the failure, after the output of GitHub CLI.
#>
param(
    [Parameter(Mandatory)] [string] $Repository,
    [Parameter(Mandatory)] [string] $OutputPath
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

Write-Host "Listing open issues of $Repository"
$json = gh issue list --repo $Repository --state open --json number,title,labels
if ($LASTEXITCODE -ne 0) {
    [Console]::Error.WriteLine("Cannot list the issues of $Repository; gh failed with exit code $LASTEXITCODE.")
    exit 2
}

$issues = ($json -join "`n") | ConvertFrom-Json
$issues | ForEach-Object {
    [pscustomobject]@{ Number = $_.number; Title = $_.title; Labels = ($_.labels.name -join ', ') }
} | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8

[Console]::Out.WriteLine('::result::' + (@{ path = $OutputPath; count = $issues.Count } | ConvertTo-Json -Compress))
```

## Tests

Cover every script with [Pester](https://pester.dev) tests that run it as a child process, so the exit code, stdout and stderr are the real ones:

```powershell
It 'returns the path of the CSV file' {
    $stdout = pwsh -NoProfile -File $script -Repository 'owner/name' -OutputPath $csv 2>$null

    $LASTEXITCODE | Should -Be 0
    $result = @($stdout | Where-Object { $_ -like '::result::*' })
    $result.Count | Should -Be 1
    ($result[0] -replace '^::result::' | ConvertFrom-Json).path | Should -Be $csv
}
```
