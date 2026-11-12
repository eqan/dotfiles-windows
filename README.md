# Workspacer setup

This repository contains the Workspacer configuration for Windows.

## One-command installation

Open **Administrator PowerShell** in this repository and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\.workspacer\install-workspacer.ps1"
```

The installer:

- Installs Workspacer with WinGet (`rickbutton.workspacer`)
- Creates the startup shortcut
- Uses this repository as the Workspacer configuration root
- Starts Workspacer with the committed configuration

## Manual start

```powershell
& ".\.workspacer\start-workspacer.cmd"
```

Useful shortcuts include `Alt+C` to close the focused window and the standard Workspacer workspace/layout shortcuts.

## Commit changes

```powershell
git add README.md .workspacer
git commit -m "Add one-command Workspacer setup"
```
