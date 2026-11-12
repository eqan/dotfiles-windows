# Full Windows Bootstrapping

This repository bootstraps a complete Windows workstation: PowerShell,
terminal tools, Workspacer, PowerToys, Vim-style AutoHotkey controls, search,
fonts, profiles, and startup tasks.

## One-command installation

Open **Administrator PowerShell** in this repository and run one command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\install.ps1"
```

The installer:

- Sets `WORKSPACER_CONFIG` to this repository
- Installs PowerShell 7
- Installs Microsoft PowerToys for keyboard remapping
- Installs Artifex's MuPDF toolkit (`mutool`), VLC, 7-Zip, and Zen Browser
- Includes an optional Chris Titus Tech WinUtil Minimal debloat step; the current
  machine is marked as already debloated so rerunning setup does not repeat it
- Configures WinUtil-style Security updates only: feature updates are deferred,
  driver delivery through Windows Update is disabled, and updates notify before install
- Installs AutoHotkey v1.1.37.02 for the repository's Vim AHK configuration
- Installs Oh My Posh and the `posh-git`, `Terminal-Icons`, and `PSReadLine` PowerShell dependencies
- Installs JetBrainsMono Nerd Font for prompt icons and configures Windows Terminal to use it
- Installs Microsoft Coreutils (`cat`, `grep`, `find`, `xargs`, and related Unix-style commands)
- Installs `lf`, `ripgrep`, `fd`, `fzf`, `bat`, `jq`, Git, and GitHub CLI
- Detects the repository's `nircmd` files
- Installs Workspacer with WinGet (`rickbutton.workspacer`)
- Builds `vim_ahk.exe` from `eqan/Windows-Automation`
- Registers Workspacer and Vim AHK as elevated startup tasks
- Uses this repository as the Workspacer configuration root
- Starts Workspacer and Vim AHK with the committed configuration

## Manual start

```powershell
& ".\.workspacer\start-workspacer.cmd"
```

Useful shortcuts include `Alt+C` to close the focused window and the standard Workspacer workspace/layout shortcuts.

The installer backs up and updates Windows Terminal's `settings.json` to use **JetBrainsMono Nerd Font**. Restart Windows Terminal after setup so the font change takes effect.

PowerToys Run is the Windows Search replacement. Press `Alt+Space` to launch it, then search for applications, files, settings, and commands.

## Debloating and default applications

The installer uses the official [Chris Titus Tech Windows Utility](https://christitus.com/windows-tool)
headlessly with its `Minimal` preset only when `$windowsAlreadyDebloated` in
`install.ps1` is set to `$false`. It is currently `$true` because this system has
already been debloated. The Minimal preset includes WinUtil's essential telemetry
protection and service/privacy settings. WinUtil requires an elevated PowerShell session.

The installer also applies WinUtil's documented **Security** Windows Update workflow:
feature updates are deferred for 365 days, quality updates for 4 days, driver delivery
through Windows Update is disabled, and Windows notifies before installation. Windows
Update remains enabled so security updates can still arrive.

WinGet installs VLC, 7-Zip, Zen Browser, and Artifex's MuPDF command-line toolkit
(`mutool`). Windows protects the current user's default-app associations; therefore
the installer does not overwrite them through unsupported registry hacks. Set VLC,
Zen Browser, and your preferred PDF handler in **Settings → Apps → Default apps**
after installation.

## Vim AHK

The installer downloads and builds the [Windows-Automation](https://github.com/eqan/Windows-Automation) Vim AHK project. It starts the compiled `vim_ahk.exe` through an elevated scheduled task at logon.

After changing the Vim AHK source, refresh it with:

```powershell
. $PROFILE
vim-refresh
```

Use `vim-refresh -NoPull` to rebuild the existing checkout without pulling from GitHub. Windows Terminal and Zen Browser are excluded from Vim AHK, and Normal mode blocks ordinary text input while preserving Vim bindings.

WinShotX is not installed or started by this setup. Use Windows' built-in
`Win+Shift+S` shortcut for Snipping Tool. The installer also removes the old
WinShotX-related PowerToys remaps if they are present.

## Commit changes

```powershell
git add README.md .workspacer
git commit -m "Add one-command Workspacer setup"
```
