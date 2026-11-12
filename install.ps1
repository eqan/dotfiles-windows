$ErrorActionPreference = 'Stop'

$repoRoot = $PSScriptRoot
$workspacerInstaller = Join-Path $repoRoot '.workspacer\install-workspacer.ps1'

if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'WinGet is unavailable. Install/update App Installer from Microsoft Store, then run this script again.'
}

function Install-WingetPackage {
    param([Parameter(Mandatory)][string] $Id)

    $installed = (& winget list --id $Id --exact --source winget `
        --accept-source-agreements 2>$null | Out-String)
    if ($installed -match [regex]::Escape($Id)) {
        Write-Host "Skipping $Id (already installed)."
        return
    }

    Write-Host "Installing $Id..."
    & winget install --id $Id --exact --source winget `
        --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "WinGet could not install $Id (exit code $LASTEXITCODE); continuing."
    }
}

# Windows-native equivalents of common Linux terminal tools.
$packages = @(
    'Microsoft.PowerShell',
    'Microsoft.PowerToys',
    'voidtools.Everything',
    'JanDeDobbeleer.OhMyPosh',
    'DEVCOM.JetBrainsMonoNerdFont',
    'Microsoft.Coreutils',
    'gokcehan.lf',
    'BurntSushi.ripgrep.MSVC',
    'sharkdp.fd',
    'junegunn.fzf',
    'sharkdp.bat',
    'jqlang.jq',
    'Git.Git',
    'GitHub.cli'
)

foreach ($package in $packages) {
    Install-WingetPackage $package
}

# Windows-Automation is written in AutoHotkey v1 syntax. Install the
# compatible runtime, build the repository, and run the compiled executable
# through an elevated logon task.
$ahkVersion = '1.1.37.02'
$ahkInstalled = (& winget list --id AutoHotkey.AutoHotkey --exact --source winget `
    --accept-source-agreements 2>$null | Out-String)
if ($ahkInstalled -match 'AutoHotkey') {
    if ($ahkInstalled -match [regex]::Escape($ahkVersion)) {
        Write-Host "Skipping AutoHotkey.AutoHotkey $ahkVersion (already installed)."
    }
    else {
        Write-Host 'Replacing incompatible AutoHotkey version with v1.1.37.02...'
        & winget uninstall --id AutoHotkey.AutoHotkey --exact --silent
        & winget install --id AutoHotkey.AutoHotkey --exact --version $ahkVersion `
            --source winget --accept-source-agreements --accept-package-agreements
    }
}
else {
    & winget install --id AutoHotkey.AutoHotkey --exact --version $ahkVersion `
        --source winget --accept-source-agreements --accept-package-agreements
}

function Install-WindowsAutomationVim {
    $automationRoot = Join-Path $env:LOCALAPPDATA 'Windows-Automation'
    $automationRepo = 'https://github.com/eqan/Windows-Automation.git'
    $buildScript = Join-Path $automationRoot 'build.bat'

    if (!(Test-Path -LiteralPath (Join-Path $automationRoot '.git'))) {
        if (Test-Path -LiteralPath $automationRoot) {
            Remove-Item -LiteralPath $automationRoot -Recurse -Force
        }
        git clone --depth 1 $automationRepo $automationRoot
        if ($LASTEXITCODE -ne 0) { throw 'Could not clone Windows-Automation.' }
    }
    else {
        git -C $automationRoot pull --ff-only
        if ($LASTEXITCODE -ne 0) { Write-Warning 'Could not update Windows-Automation; using its current files.' }
    }

    if (!(Test-Path -LiteralPath $buildScript)) { throw "Windows-Automation build script not found: $buildScript" }
    Push-Location $automationRoot
    try {
        & cmd.exe /d /c '.\build.bat'
        if ($LASTEXITCODE -ne 0) { throw "Windows-Automation build failed with exit code $LASTEXITCODE." }
    }
    finally {
        Pop-Location
    }

    $vimExe = Get-ChildItem -LiteralPath $automationRoot -Recurse -File `
        -Filter 'vim_ahk.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (!$vimExe) { throw 'Windows-Automation build completed without producing vim_ahk.exe.' }

    $taskName = 'AutoHotkey Vim (Windows-Automation)'
    $userId = "$env:USERDOMAIN\$env:USERNAME"
    $taskAction = New-ScheduledTaskAction -Execute $vimExe.FullName -WorkingDirectory $vimExe.DirectoryName
    $taskTrigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
    $taskPrincipal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest
    $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Settings $taskSettings -Force | Out-Null
    Start-ScheduledTask -TaskName $taskName
    Write-Host 'Configured elevated startup: AutoHotkey Vim (Windows-Automation)'
}

Install-WindowsAutomationVim

function Configure-PowerToysRemaps {
    $keyboardManagerPath = Join-Path $env:LOCALAPPDATA 'Microsoft\PowerToys\Keyboard Manager'
    $profilePath = Join-Path $keyboardManagerPath 'default.json'
    New-Item -ItemType Directory -Path $keyboardManagerPath -Force | Out-Null

    try {
        Get-Process PowerToys -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction Stop
    }
    catch {
        Write-Warning 'Could not stop PowerToys; close it before rerunning setup if the remap does not activate.'
    }

    $settingsCli = Get-Command PowerToys.Settings.CLI.exe -ErrorAction SilentlyContinue
    if (!$settingsCli) {
        $settingsCli = Get-ChildItem 'C:\Program Files\PowerToys' -Filter 'PowerToys.Settings.CLI.exe' `
            -File -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if ($settingsCli) {
        $settingsCliPath = if ($settingsCli.Source) { $settingsCli.Source } else { $settingsCli.FullName }
        & $settingsCliPath enable KeyboardManager
        & $settingsCliPath enable PowerLauncher
        Write-Host 'Enabled PowerToys Keyboard Manager and PowerToys Run.'
    }
    else {
        Write-Warning 'PowerToys.Settings.CLI.exe was not found; utilities must be enabled manually.'
    }

    if (Test-Path -LiteralPath $profilePath) {
        $profile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
        Copy-Item -LiteralPath $profilePath -Destination "$profilePath.bak" -Force
    }
    else {
        $profile = [pscustomobject]@{}
    }

    if (!$profile.PSObject.Properties['remapShortcuts']) {
        $profile | Add-Member -NotePropertyName remapShortcuts -NotePropertyValue ([pscustomobject]@{})
    }
    if (!$profile.remapShortcuts.PSObject.Properties['global']) {
        $profile.remapShortcuts | Add-Member -NotePropertyName global -NotePropertyValue @()
    }

    # Remove the old custom screenshot remaps. Win+Shift+S remains owned by
    # Windows Snipping Tool, and no WinShotX shortcut is installed.
    $profile.remapShortcuts.global = @($profile.remapShortcuts.global) |
        Where-Object { $_.originalKeys -ne '91;160;83' -and $_.originalKeys -ne '162;160;83' }

    $profile | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $profilePath -Encoding UTF8
    Write-Host 'Removed obsolete WinShotX screenshot remaps from PowerToys'

    $powerToysExe = 'C:\Program Files\PowerToys\PowerToys.exe'
    if (Test-Path -LiteralPath $powerToysExe) {
        Start-Process -FilePath $powerToysExe
    }
}

Configure-PowerToysRemaps

function Add-StartupShortcut {
    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][string] $Target,
        [string] $Arguments = '',
        [string] $WorkingDirectory = ''
    )

    if (!(Test-Path -LiteralPath $Target)) { return }
    $startupDirectory = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
    $shortcutPath = Join-Path $startupDirectory "$Name.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $Target
    $shortcut.Arguments = $Arguments
    $shortcut.WorkingDirectory = if ($WorkingDirectory) { $WorkingDirectory } else { Split-Path -Parent $Target }
    $shortcut.Save()
    Write-Host "Configured startup: $Name"
}

$workspacerLauncher = Join-Path $repoRoot '.workspacer\start-workspacer.cmd'
Add-StartupShortcut -Name 'workspacer-dotfiles' -Target $workspacerLauncher -WorkingDirectory $repoRoot

$powerToysStartupTarget = 'C:\Program Files\PowerToys\PowerToys.exe'
$powerToysStartupArguments = ''
if (!(Test-Path -LiteralPath $powerToysStartupTarget)) {
    $powerToysCommand = Get-Command PowerToys.exe -ErrorAction SilentlyContinue
    if ($powerToysCommand) {
        $powerToysStartupTarget = $powerToysCommand.Source
    }
    else {
        $powerToysPackage = Get-AppxPackage -Name Microsoft.PowerToys -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($powerToysPackage) {
            $packagedExe = Get-ChildItem -LiteralPath $powerToysPackage.InstallLocation -Recurse -Filter 'PowerToys.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($packagedExe) {
                $powerToysStartupTarget = $packagedExe.FullName
            }
            else {
                $powerToysStartupTarget = Join-Path $env:WINDIR 'explorer.exe'
                $powerToysStartupArguments = "shell:AppsFolder\$($powerToysPackage.PackageFamilyName)!PowerToys"
            }
        }
    }
}

$powerToysShortcut = Join-Path (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup') 'PowerToys.lnk'
if (Test-Path -LiteralPath $powerToysShortcut) { Remove-Item -LiteralPath $powerToysShortcut -Force }
if (Test-Path -LiteralPath $powerToysStartupTarget) {
    $powerToysTaskName = 'PowerToys (elevated)'
    $userId = "$env:USERDOMAIN\$env:USERNAME"
    $taskAction = New-ScheduledTaskAction -Execute $powerToysStartupTarget -Argument $powerToysStartupArguments -WorkingDirectory (Split-Path -Parent $powerToysStartupTarget)
    $taskTrigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
    $taskPrincipal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest
    $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $powerToysTaskName -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Settings $taskSettings -Force | Out-Null
    if (!(Get-Process PowerToys -ErrorAction SilentlyContinue)) { Start-ScheduledTask -TaskName $powerToysTaskName }
    Write-Host 'Configured elevated startup: PowerToys'
}
else {
    Write-Warning 'PowerToys executable/package was not found; startup task was not created.'
}

$everythingExe = @(
    'C:\Program Files\Everything\Everything.exe',
    'C:\Program Files (x86)\Everything\Everything.exe'
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (!$everythingExe) {
    $everythingCommand = Get-Command Everything.exe -ErrorAction SilentlyContinue
    if ($everythingCommand) { $everythingExe = $everythingCommand.Source }
}
if ($everythingExe) { Add-StartupShortcut -Name 'Everything' -Target $everythingExe }

# Remove a stale shortcut left by older installers.
$staleWinShotXShortcut = Join-Path (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup') 'WinShotX.lnk'
if (Test-Path -LiteralPath $staleWinShotXShortcut) {
    Remove-Item -LiteralPath $staleWinShotXShortcut -Force
    Write-Host 'Removed stale WinShotX startup shortcut'
}

# Configure Windows Terminal to render Nerd Font prompt icons. Windows
# Terminal uses JSONC, so update only the fontFace property and preserve the
# rest of the user's settings text.
$terminalSettings = @(
    (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
    (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json')
)
foreach ($settingsPath in $terminalSettings) {
    if (!(Test-Path -LiteralPath $settingsPath)) { continue }

    $settingsText = Get-Content -LiteralPath $settingsPath -Raw
    $updatedSettings = $settingsText
    if ($updatedSettings -match '"fontFace"\s*:') {
        $fontPattern = [regex]::new('"fontFace"\s*:\s*"(?:\\.|[^"\\])*"')
        $updatedSettings = $fontPattern.Replace(
            $updatedSettings,
            '"fontFace": "JetBrainsMono Nerd Font"',
            1)
    }
    elseif ($updatedSettings -match '"defaults"\s*:\s*\{') {
        $defaultsPattern = [regex]::new('"defaults"\s*:\s*\{')
        $updatedSettings = $defaultsPattern.Replace(
            $updatedSettings,
            '"defaults": { "fontFace": "JetBrainsMono Nerd Font",',
            1)
    }

    if ($updatedSettings -ne $settingsText) {
        Copy-Item -LiteralPath $settingsPath -Destination "$settingsPath.bak" -Force
        Set-Content -LiteralPath $settingsPath -Value $updatedSettings -Encoding UTF8
        Write-Host "Configured Windows Terminal font: $settingsPath"
    }
}

# PowerShell Gallery modules referenced by the repository profile.
if (Get-Command Install-Module -ErrorAction SilentlyContinue) {
    try {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop | Out-Null
        foreach ($module in @('posh-git', 'Terminal-Icons', 'PSReadLine')) {
            $available = Get-Module -ListAvailable -Name $module |
                Sort-Object Version -Descending |
                Select-Object -First 1
            $needsUpdate = ($module -eq 'PSReadLine' -and
                (!$available -or [version]$available.Version -lt [version]'2.2.0'))
            if ($available -and !$needsUpdate) {
                Write-Host "Skipping PowerShell module $module (already installed)."
            }
            else {
                Write-Host "Installing PowerShell module $module..."
                Install-Module -Name $module -Scope CurrentUser -Repository PSGallery `
                    -Force -AllowClobber -ErrorAction Stop
            }
        }
    }
    catch {
        Write-Warning "PowerShell module setup failed: $($_.Exception.Message)"
    }
}

# Install the repository PowerShell profile into the locations PowerShell
# loads automatically for the current user.
try {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
    Write-Host 'PowerShell profile execution enabled for the current user.'
}
catch {
    Write-Warning "Could not set the current-user execution policy: $($_.Exception.Message)"
}

$profileSource = Get-ChildItem -LiteralPath $repoRoot -Recurse -File `
    -Filter 'Microsoft.PowerShell_profile.ps1' `
    -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\.git\\' } |
    Select-Object -First 1

if ($profileSource) {
    $documents = [Environment]::GetFolderPath('MyDocuments')
    $profileTargets = @(
        (Join-Path $documents 'PowerShell\Microsoft.PowerShell_profile.ps1'),
        (Join-Path $documents 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1')
    )

    foreach ($target in $profileTargets) {
        $targetDirectory = Split-Path -Parent $target
        New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
        if (Test-Path -LiteralPath $target) {
            Copy-Item -LiteralPath $target -Destination "$target.bak" -Force
        }
        Copy-Item -LiteralPath $profileSource.FullName -Destination $target -Force

        # Oh My Posh is an executable installed by WinGet, not a PowerShell
        # module. Normalize old profile lines and avoid missing theme errors.
        $profileText = Get-Content -LiteralPath $target -Raw
        $profileText = [regex]::Replace(
            $profileText,
            '(?m)^\s*Import-Module\s+oh-my-posh\s*\r?$\r?\n?',
            '')

        $theme = Get-ChildItem -LiteralPath $repoRoot -Recurse -File `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notmatch '\\.git\\' -and
                $_.Extension -eq '.json' -and
                $_.Name -like '*.omp.json'
            } |
            Select-Object -First 1
        $themePath = if ($theme) { $theme.FullName } else { $null }
        $initLine = if ($themePath) {
            "if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) { oh-my-posh init powershell --config '$themePath' | Invoke-Expression }"
        }
        else {
            "if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) { oh-my-posh init powershell | Invoke-Expression }"
        }
        $profileText = [regex]::Replace(
            $profileText,
            '(?m)^\s*oh-my-posh\s+.*\r?$\r?\n?',
            "$initLine`r`n")
        Set-Content -LiteralPath $target -Value $profileText -Encoding UTF8
        Write-Host "Enabled PowerShell profile: $target"
    }
}
else {
    Write-Warning 'No Microsoft.PowerShell_profile.ps1 was found in the repository.'
}

# NirCmd is kept in this repository when present; install it from the repo's
# nircmd folder without replacing a user-managed copy.
$nircmd = Join-Path $repoRoot 'nircmd'
if (Test-Path -LiteralPath $nircmd) {
    Write-Host "NirCmd files found in $nircmd"
}

[Environment]::SetEnvironmentVariable('WORKSPACER_CONFIG', $repoRoot, 'User')
$env:WORKSPACER_CONFIG = $repoRoot

if (Test-Path -LiteralPath $workspacerInstaller) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $workspacerInstaller
}
else {
    Write-Warning "Workspacer installer not found: $workspacerInstaller"
}

Write-Host 'Dotfiles bootstrap completed.'
