# Part of fixture-app.ps1 (dot-sourced when -TriggerFolder is set): the Waiter window, whose elements
# change some time after a test asks, so the tests of wait can watch UI change asynchronously.
# A file <change>.trigger in -TriggerFolder, holding a delay in ms, makes that change after the delay:
#   add     — adds Button AddedLater
#   remove  — removes Button RemoveLater
#   enable  — enables Button EnableLater (disabled at start)

$waiter = [FixtureForm] @{ Name = 'WaiterForm'; Text = 'Waiter'; Width = 400; Height = 300; StartPosition = 'Manual'; Left = 700; Top = 100 }
$waiterLayout = [System.Windows.Forms.FlowLayoutPanel] @{ Name = 'WaiterLayout'; Dock = 'Fill' }
$waiter.Controls.Add($waiterLayout)
$removeLater = New-Control Button RemoveLater Remove $waiterLayout
(New-Control Button EnableLater Enable $waiterLayout).Enabled = $false

$changes = @{
    add = { $null = New-Control Button AddedLater Added $waiterLayout }
    remove = { $waiterLayout.Controls.Remove($removeLater); $removeLater.Dispose() }
    enable = { $waiterLayout.Controls['EnableLater'].Enabled = $true }
}
$due = [System.Collections.Generic.List[object]]::new()
$timer = [System.Windows.Forms.Timer] @{ Interval = 50 }
$timer.add_Tick({
    foreach ($file in Get-ChildItem -LiteralPath $TriggerFolder -Filter '*.trigger') {
        $due.Add([pscustomobject] @{ Change = $changes[$file.BaseName]; At = (Get-Date).AddMilliseconds([int] (Get-Content -LiteralPath $file.FullName)) })
        Remove-Item -LiteralPath $file.FullName
    }
    foreach ($item in @($due | Where-Object At -le (Get-Date))) {
        & $item.Change
        $null = $due.Remove($item)
    }
})
$timer.Start()
$waiter.Show()
