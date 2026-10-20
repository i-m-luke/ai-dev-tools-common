# Stands in for GitHub CLI in the manage-github-issues script tests: answers a call by the first rule in
# $env:GH_STUB_RULES whose `match` regex matches the space-joined arguments, and appends the call to
# $env:GH_STUB_LOG.
$stdin = @($input) -join "`n"
$call = [ordered] @{ args = @($args); stdin = if ($stdin) { $stdin } else { $null } }
Add-Content -LiteralPath $env:GH_STUB_LOG -Value (ConvertTo-Json -InputObject $call -Compress -Depth 5) -Encoding UTF8

$line = $args -join ' '
foreach ($rule in (Get-Content -Raw -LiteralPath $env:GH_STUB_RULES | ConvertFrom-Json)) {
    if ($line -match $rule.match) {
        if ($null -ne $rule.stdout) { $rule.stdout }
        if ($rule.stderr) { Write-Error $rule.stderr }
        exit ([int] $rule.exit)
    }
}

Write-Error "gh stub: no rule matches '$line'"
exit 99
