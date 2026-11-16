# Full Windows Bootstrapping

This repository bootstraps a complete Windows workstation: PowerShell,
terminal tools, komorebi, Vim-style AutoHotkey controls, search,
fonts, profiles, and startup tasks.

## One-command installation

Open **Administrator PowerShell** in this repository and run one command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\install.ps1"
```

The installer:

- Sets `WORKSPACER_CONFIG` to this repository
- Installs PowerShell 7
- Installs komorebi and whkd for lightweight Rust-based tiling and Alt-key controls
- Installs Artifex's MuPDF toolkit (`mutool`), VLC, 7-Zip, and Zen Browser
- Includes an optional Chris Titus Tech WinUtil Minimal debloat step; the current
  machine is marked as already debloated so rerunning setup does not repeat it
- Configures WinUtil-style Security updates only: feature updates are deferred,
  driver delivery through Windows Update is disabled, and updates notify before install
- At the start, optionally enables battery C-state-friendly power settings: processor
  idle and core parking, 5% minimum battery processor state, and maximum PCIe ASPM
- Installs AutoHotkey v1.1.37.02 for the repository's Vim AHK configuration
- Installs PSReadLine; the profile uses a minimal native prompt with no prompt framework,
  `posh-git`, or `Terminal-Icons` startup dependency
- Installs WezTerm, a Rust terminal emulator with tabs and panes, configured to launch
  PowerShell 7 by default
- Installs native Unix-oriented tools: eza, zoxide, and Yazi, alongside Microsoft Coreutils
- Installs JetBrainsMono Nerd Font for prompt icons and configures Windows Terminal to use it
- Installs Microsoft Coreutils (`cat`, `grep`, `find`, `xargs`, and related Unix-style commands)
- Installs `lf`, `ripgrep`, `fd`, `fzf`, `bat`, `jq`, Git, and GitHub CLI
- Detects the repository's `nircmd` files
- Configures komorebi's built-in bar with workspace numbers, layout, focused title,
  CPU, storage, memory, network, battery, date, and time widgets
- Configures the native Windows taskbar to persistent auto-hide so only komorebi-bar
  remains visible during normal use
- Hides desktop icons by default; `Ctrl+Alt+D` in Vim AHK toggles them for temporary access
- Builds `vim_ahk.exe` from `eqan/Windows-Automation`
- Configures Vim AHK `Win+X` to launch elevated WezTerm instead of Windows Terminal
- Registers komorebi and Vim AHK as elevated startup tasks with a three-second delay
- Cleans up stale `whkd` instances before starting the elevated Komorebi hotkey daemon
- Uses the committed `komorebi/` configuration and disables the old Workspacer startup task
- Removes replaced applications such as Workspacer, YASB, PowerToys, Flow Launcher,
  Brave, and WinShotX when they are still installed
- Starts komorebi, its built-in bar, whkd, and Vim AHK with the committed configuration

## Manual start

```powershell
& "C:\Program Files\komorebi\bin\komorebic.exe" start
```

komorebi uses `Alt` as its modifier: `Alt+H/J/K/L` moves focus, `Alt+Shift+H/L`
shrinks/expands the primary column, `Alt+Shift+J/K` adjusts vertical sizing,
`Alt+1..9` switches workspaces, and `Alt+Space` cycles layouts. Window movement
uses `Ctrl+Alt+H/J/K/L` so it does not conflict with resizing.
`Alt+C` and `Alt+Q` close the focused window. The built-in bar shows workspace numbers,
layout, focused title, CPU, storage, memory, network, battery, a compact date, and time.

If the hotkeys become unresponsive, press `Win+O` or run
`powershell -File .\komorebi\restart-komorebi.ps1`. This releases stuck modifier state,
cleans stale Komorebi/whkd processes, and restarts the single elevated stack.

PowerShell shortcuts include `vim-ahk` to enter the Windows-Automation checkout and
`dotfiles` to enter this repository. Tab accepts an inline history suggestion; when
no suggestion exists, it opens normal command and file completion.

PowerShell uses PSReadLine's native Vi editing mode. Vim AHK remains available for
other applications but is explicitly disabled inside WezTerm.

The installer backs up and updates Windows Terminal's `settings.json` to use **JetBrainsMono Nerd Font**. Restart Windows Terminal after setup so the font change takes effect.

Flameshot is the lightweight screenshot replacement. The bootstrap removes the
per-user Microsoft Snipping Tool package. WezTerm is the terminal replacement;
the bootstrap also removes the per-user Windows Terminal package when present.
Flameshot supports region,
window, fullscreen, clipboard, annotation, blur, and export workflows without
the larger ShareX suite. `Win+Shift+S` starts region capture and copies the
result to the clipboard; Flameshot is started automatically at logon.

Keypirinha is the lightweight Spotlight-style search replacement. Its explicit
shortcut is `Ctrl+Alt+S`, and Vim AHK forwards `Win+S` to it. Its built-in
Everything package uses the already-running Everything index for fast file and
application search. Flow Launcher is disabled and is no longer installed by the
bootstrap.

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

### Battery C-state optimization

The bootstrap asks whether to apply the optional battery optimization near startup.
Answer `y` or `yes` to configure the active power plan with processor idle enabled,
core parking allowed, a 5% minimum processor state on battery, and maximum PCIe
link-state power savings. Answering anything else skips it. These settings allow
deeper idle states but cannot force a particular C-state; CPU firmware, drivers, and
active devices determine the final residency.

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

WinShotX is not installed or started by this setup. Flameshot handles
`Win+Shift+S` region capture and copies the result to the clipboard. The
installer removes old WinShotX and PowerToys remnants.

## Commit changes

```powershell
git add README.md .workspacer komorebi install.ps1
git commit -m "Add lightweight komorebi desktop setup"
```
