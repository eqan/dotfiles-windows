# Workspacer setup

This repository contains the Workspacer configuration for Windows.

## One-command installation

Open **Administrator PowerShell** in this repository and run one command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\install.ps1"
```

The installer:

- Sets `WORKSPACER_CONFIG` to this repository
- Installs PowerShell 7
- Installs Microsoft PowerToys for keyboard remapping
- Installs Everything for instant file-name indexing/search
- Installs Oh My Posh and the `posh-git`, `Terminal-Icons`, and `PSReadLine` PowerShell dependencies
- Installs JetBrainsMono Nerd Font for prompt icons and configures Windows Terminal to use it
- Installs Microsoft Coreutils (`cat`, `grep`, `find`, `xargs`, and related Unix-style commands)
- Installs `lf`, `ripgrep`, `fd`, `fzf`, `bat`, `jq`, Git, and GitHub CLI
- Detects the repository's `nircmd` files
- Installs Workspacer with WinGet (`rickbutton.workspacer`)
- Creates the startup shortcut
- Uses this repository as the Workspacer configuration root
- Starts Workspacer with the committed configuration

## Manual start

```powershell
& ".\.workspacer\start-workspacer.cmd"
```

Useful shortcuts include `Alt+C` to close the focused window and the standard Workspacer workspace/layout shortcuts.

The installer backs up and updates Windows Terminal's `settings.json` to use **JetBrainsMono Nerd Font**. Restart Windows Terminal after setup so the font change takes effect.

PowerToys Run is the Windows Search replacement. Press `Alt+Space` to launch it, then search for applications, files, settings, and commands. Everything provides the fast file index used for file searches.

WinShotX is not installed or started by this setup. Use Windows' built-in
`Win+Shift+S` shortcut for Snipping Tool. The installer also removes the old
WinShotX-related PowerToys remaps if they are present.

## Commit changes

```powershell
git add README.md .workspacer
git commit -m "Add one-command Workspacer setup"
```
