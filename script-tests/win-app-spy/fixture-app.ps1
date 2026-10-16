# A small WinForms app with known elements for the win-app-spy tests; it runs until its process is stopped.
# Its windows open without taking focus, so they do not disturb other apps on the desktop.
# Writes -ReadyFile once its windows are shown. -WithActForm adds the Act window for the act tests:
# its ActLog edit box records what the other controls receive. With -TriggerFolder it also shows the
# Waiter window of fixture-waiter.ps1, whose elements change on request.
param([Parameter(Mandatory)] [string] $ReadyFile, [switch] $WithActForm, [string] $TriggerFolder)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -ReferencedAssemblies System.Windows.Forms, System.Windows.Forms.Primitives, System.ComponentModel.Primitives, System.Drawing.Primitives -TypeDefinition @'
public class FixtureForm : System.Windows.Forms.Form
{
    protected override bool ShowWithoutActivation => true;
}
'@

function New-Control([string] $type, [string] $name, [string] $text, [System.Windows.Forms.Control] $parent) {
    $control = New-Object "System.Windows.Forms.$type"
    $control.Name = $name
    $control.Text = $text
    $control.AutoSize = $true
    $parent.Controls.Add($control)
    $control
}

$main = [FixtureForm] @{ Name = 'MainForm'; Text = 'Fixture'; Width = 600; Height = 400; StartPosition = 'Manual'; Left = 100; Top = 100 }
$layout = [System.Windows.Forms.FlowLayoutPanel] @{ Name = 'Layout'; Dock = 'Fill' }
$main.Controls.Add($layout)
(New-Control CheckBox WrapBox Wrap $layout).Checked = $true
$null = New-Control Button SaveBtn Save $layout
(New-Control Button CancelBtn Cancel $layout).Enabled = $false
$null = New-Control Button OkA OK $layout
$null = New-Control Button OkB OK $layout
$null = New-Control TextBox NameBox hello $layout
$group = [System.Windows.Forms.FlowLayoutPanel] @{ Name = 'Group'; AutoSize = $true; BorderStyle = 'FixedSingle' }
$layout.Controls.Add($group)
$null = New-Control Button InnerBtn Inner $group
foreach ($i in 1..6) { $null = New-Control Button "Item$i" Item $group }

$dialog = [FixtureForm] @{ Name = 'DialogForm'; Text = 'Dialog'; Width = 300; Height = 200; StartPosition = 'Manual'; Left = 300; Top = 300 }
$null = New-Control Button DialogOk OK $dialog

if ($WithActForm) {
    $act = [FixtureForm] @{ Name = 'ActForm'; Text = 'Act'; Width = 500; Height = 400; StartPosition = 'Manual'; Left = 700; Top = 100 }
    $actLayout = [System.Windows.Forms.FlowLayoutPanel] @{ Name = 'ActLayout'; Dock = 'Fill' }
    $act.Controls.Add($actLayout)
    $log = [System.Windows.Forms.TextBox] @{ Name = 'ActLog'; ReadOnly = $true; Width = 450 }
    $actLayout.Controls.Add($log)
    function Write-ActLog([string] $entry) { $log.Text = ($log.Text + ' ' + $entry).Trim() }

    $pad = [System.Windows.Forms.Panel] @{ Name = 'Pad'; Width = 120; Height = 60; BackColor = 'LightSteelBlue' }
    $pad.add_MouseDown({ param($s, $e) Write-ActLog "$($e.Button)$($e.Clicks)" })
    $actLayout.Controls.Add($pad)
    (New-Control Button InvokeBtn Invoke $actLayout).add_Click({ Write-ActLog 'invoked' })
    (New-Control Button OffBtn Off $actLayout).Enabled = $false
    $typeBox = [System.Windows.Forms.TextBox] @{ Name = 'TypeBox'; Width = 200 }
    $typeBox.add_GotFocus({ Write-ActLog 'focus' })
    $actLayout.Controls.Add($typeBox)
    $null = New-Control CheckBox FlagA Flag $actLayout
    $null = New-Control CheckBox FlagB Flag $actLayout
    $tree = [System.Windows.Forms.TreeView] @{ Name = 'Tree'; Width = 200; Height = 120; HideSelection = $false }
    $alpha = $tree.Nodes.Add('Alpha')
    $null = $alpha.Nodes.Add('Beta')
    $null = $tree.Nodes.Add('Gamma')
    $actLayout.Controls.Add($tree)
    $act.Show()
}

$main.Show()
$dialog.Show()
if ($TriggerFolder) { . (Join-Path $PSScriptRoot 'fixture-waiter.ps1') }
[System.Windows.Forms.Application]::DoEvents()
Set-Content -LiteralPath $ReadyFile -Value $PID
[System.Windows.Forms.Application]::Run()
