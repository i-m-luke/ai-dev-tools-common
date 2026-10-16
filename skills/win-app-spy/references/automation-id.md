# Setting an AutomationId

Choose an id that is unique among the element's siblings and independent of the UI language, e.g.
`SaveButton`. Inside an item template, bind the id to a per-item key so the items stay
distinguishable.

## WPF

```xml
<Button AutomationProperties.AutomationId="SaveButton" />
```

```csharp
// System.Windows.Automation
AutomationProperties.SetAutomationId(saveButton, "SaveButton");
```

Without it, WPF reports the element's `x:Uid`, then its `Name`, as the AutomationId.

## WinForms

The AutomationId is the control's `Name`. The designer sets it in `*.Designer.cs`; controls created
in code often lack it.

```csharp
saveButton.Name = "SaveButton";
```

`AccessibleName` sets the UI Automation `Name`, not the AutomationId.

## WinUI 3, UWP and Uno Platform

```xml
<Button AutomationProperties.AutomationId="SaveButton" />
```

```csharp
// Microsoft.UI.Xaml.Automation (WinUI 3, Uno Platform); Windows.UI.Xaml.Automation (UWP)
AutomationProperties.SetAutomationId(saveButton, "SaveButton");
```

## .NET MAUI

```xml
<Button AutomationId="SaveButton" />
```

```csharp
saveButton.AutomationId = "SaveButton";
```

`AutomationId` can be set only once per element; on Windows it becomes the native control's
AutomationId.

## Avalonia

```xml
<Button AutomationProperties.AutomationId="SaveButton" />
```

```csharp
// Avalonia.Automation
AutomationProperties.SetAutomationId(saveButton, "SaveButton");
```

Without it, Avalonia reports the control's `Name` as the AutomationId.
