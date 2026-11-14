$ErrorActionPreference = 'Stop'

$repoRoot = $PSScriptRoot
$workspacerInstaller = Join-Path $repoRoot '.workspacer\install-workspacer.ps1'

if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'WinGet is unavailable. Install/update App Installer from Microsoft Store, then run this script again.'
}

function Enable-BatteryCStateOptimization {
    Write-Host ''
    Write-Host 'Optional battery / CPU idle optimization' -ForegroundColor Cyan
    Write-Host 'This enables Windows settings that allow deeper processor idle states:'
    Write-Host '  - processor idle enabled and core parking allowed'
    Write-Host '  - 5% minimum processor state on battery'
    Write-Host '  - maximum PCIe link-state power savings on battery'
    Write-Host 'Firmware and the CPU still control the actual C-state residency.'

    $answer = Read-Host 'Apply these battery C-state-friendly settings now? [y/N]'
    if ($answer -notmatch '^(?i:y|yes)$') {
        Write-Host 'Skipping battery / CPU idle optimization.'
        return
    }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Battery C-state optimization requires an Administrator PowerShell session.'
    }

    $settings = @(
        @{ Subgroup = 'SUB_PROCESSOR'; Setting = 'IDLEDISABLE'; Value = 0 },
        @{ Subgroup = 'SUB_PROCESSOR'; Setting = 'IDLEDEMOTE'; Value = 40 },
        @{ Subgroup = 'SUB_PROCESSOR'; Setting = 'IDLEPROMOTE'; Value = 20 },
        @{ Subgroup = 'SUB_PROCESSOR'; Setting = 'PROCTHROTTLEMIN'; Value = 5 },
        @{ Subgroup = 'SUB_PROCESSOR'; Setting = 'CPMINCORES'; Value = 0 },
        @{ Subgroup = 'SUB_PCIEXPRESS'; Setting = 'ASPM'; Value = 2 }
    )

    foreach ($setting in $settings) {
        & powercfg /setdcvalueindex scheme_current $setting.Subgroup $setting.Setting $setting.Value
        if ($LASTEXITCODE -ne 0) {
            throw "Could not apply battery power setting $($setting.Setting)."
        }
    }

    & powercfg /setactive scheme_current
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not re-activate the current power plan.'
    }

    Write-Host 'Applied battery C-state-friendly settings to the current power plan.' -ForegroundColor Green
}

Enable-BatteryCStateOptimization

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

# Keep this true on machines that have already had the Windows cleanup applied.
# Set it to $false on a fresh installation to run Chris Titus Tech's Minimal preset.
$windowsAlreadyDebloated = $true

function Invoke-ChrisTitusMinimalDebloat {
    if ($windowsAlreadyDebloated) {
        Write-Host 'Skipping Chris Titus Tech Minimal debloat (windowsAlreadyDebloated = $true).'
        return
    }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Chris Titus Tech Minimal debloat requires an Administrator PowerShell session.'
    }

    Write-Host 'Applying Chris Titus Tech WinUtil Minimal preset...'
    $winUtil = Invoke-RestMethod 'https://christitus.com/win'
    & ([ScriptBlock]::Create($winUtil)) -Preset Minimal
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Chris Titus Tech WinUtil Minimal preset failed with exit code $LASTEXITCODE."
    }
}

Invoke-ChrisTitusMinimalDebloat

function Set-SecurityOnlyWindowsUpdates {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Security-only Windows Update configuration requires an Administrator PowerShell session.'
    }

    # Mirrors WinUtil's documented Updates > Security workflow:
    # https://github.com/ChrisTitusTech/winutil/blob/main/functions/public/Invoke-WPFUpdatessecurity.ps1
    $updatePolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    $automaticUpdatePolicyPath = Join-Path $updatePolicyPath 'AU'
    $driverPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching'

    New-Item -Path $driverPolicyPath -Force | Out-Null
    Set-ItemProperty -Path $driverPolicyPath -Name DontPromptForWindowsUpdate -Type DWord -Value 1
    Set-ItemProperty -Path $driverPolicyPath -Name DontSearchWindowsUpdate -Type DWord -Value 1
    Set-ItemProperty -Path $driverPolicyPath -Name DriverUpdateWizardWuSearchEnabled -Type DWord -Value 0

    New-Item -Path $updatePolicyPath -Force | Out-Null
    Set-ItemProperty -Path $updatePolicyPath -Name ExcludeWUDriversInQualityUpdate -Type DWord -Value 1
    Set-ItemProperty -Path $updatePolicyPath -Name DeferFeatureUpdates -Type DWord -Value 1
    Set-ItemProperty -Path $updatePolicyPath -Name DeferFeatureUpdatesPeriodInDays -Type DWord -Value 365
    Set-ItemProperty -Path $updatePolicyPath -Name DeferQualityUpdates -Type DWord -Value 1
    Set-ItemProperty -Path $updatePolicyPath -Name DeferQualityUpdatesPeriodInDays -Type DWord -Value 4

    New-Item -Path $automaticUpdatePolicyPath -Force | Out-Null
    Remove-ItemProperty -Path $automaticUpdatePolicyPath -Name NoAutoRebootWithLoggedOnUsers -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $automaticUpdatePolicyPath -Name AUOptions -Type DWord -Value 3
    Set-ItemProperty -Path $automaticUpdatePolicyPath -Name AUPowerManagement -Type DWord -Value 0
    Write-Host 'Configured WinUtil-style security-only Windows Update settings.'
}

Set-SecurityOnlyWindowsUpdates

# ---- package installation ----
$packages = @(
    'Microsoft.PowerShell',
    'Neovim.Neovim',
    'Microsoft.PowerToys',
    'ArtifexSoftware.mutool',
    'VideoLAN.VLC',
    '7zip.7zip',
    'Zen-Team.Zen-Browser',
    'DEVCOM.JetBrainsMonoNerdFont',
    'Microsoft.Coreutils',
    'wez.wezterm',
    'eza-community.eza',
    'ajeetdsouza.zoxide',
    'sxyazi.yazi',
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

# ---- WezTerm configuration ----
$weztermSource = Join-Path $repoRoot 'wezterm\wezterm.lua'
if (Test-Path -LiteralPath $weztermSource) {
    $weztermTarget = Join-Path $env:USERPROFILE '.wezterm.lua'
    if (Test-Path -LiteralPath $weztermTarget) {
        Copy-Item -LiteralPath $weztermTarget -Destination "$weztermTarget.bak" -Force
    }
    Copy-Item -LiteralPath $weztermSource -Destination $weztermTarget -Force
    Write-Host "Configured WezTerm with PowerShell 7 as the default shell: $weztermTarget"
}

# ---- (unchanged) AutoHotkey v1 setup ----
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

# ---- (unchanged) Windows-Automation build & scheduled task ----
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

    $customCommands = Join-Path $automationRoot 'lib\custom_commands.ahk'
    if (Test-Path -LiteralPath $customCommands) {
        $customText = Get-Content -LiteralPath $customCommands -Raw
        $updatedCustomText = [regex]::Replace(
            $customText,
            '(?m)^\s*Run \*RunAs wt, , max\s*$',
            '  Run *RunAs "C:\Program Files\WezTerm\wezterm-gui.exe", , max')
        if ($updatedCustomText -ne $customText) {
            Set-Content -LiteralPath $customCommands -Value $updatedCustomText -Encoding UTF8
            Write-Host 'Configured AutoHotkey Win+X to launch elevated WezTerm.'
        }
    }

    $vimSource = Join-Path $automationRoot 'lib\vim_ahk.ahk'
    if (Test-Path -LiteralPath $vimSource) {
        $vimText = Get-Content -LiteralPath $vimSource -Raw
        $exclusionReplacement = '    if WinActive("ahk_exe WindowsTerminal.exe") || WinActive("ahk_exe wt.exe") || WinActive("ahk_exe wezterm-gui.exe") || WinActive("ahk_exe wezterm.exe") || WinActive("ahk_exe zen.exe"){'+[Environment]::NewLine+'      Return False'+[Environment]::NewLine+'    }'
        $updatedVimText = $vimText -replace '(?m)^\s*if WinActive\("ahk_exe WindowsTerminal\.exe"\).*?\{\r?\n\s*Return False\r?\n\s*\}', $exclusionReplacement
        if ($updatedVimText -ne $vimText) {
            Set-Content -LiteralPath $vimSource -Value $updatedVimText -Encoding UTF8
            Write-Host 'Configured Vim AHK to stay disabled in WezTerm.'
        }
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
    $vimLauncher = Join-Path $PSScriptRoot '.workspacer\start-vim-ahk.vbs'
    if (!(Test-Path -LiteralPath $vimLauncher)) { throw "Vim AHK launcher not found: $vimLauncher" }
    $taskAction = New-ScheduledTaskAction -Execute (Join-Path $env:WINDIR 'System32\wscript.exe') `
        -Argument "`"$vimLauncher`" `"$($vimExe.FullName)`"" `
        -WorkingDirectory $vimExe.DirectoryName
    $taskTrigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
    $taskPrincipal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest
    $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
        -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Settings $taskSettings -Force | Out-Null
    Start-ScheduledTask -TaskName $taskName
    Write-Host 'Configured elevated startup: AutoHotkey Vim (Windows-Automation)'
}

Install-WindowsAutomationVim

# ---- (unchanged) PowerToys remaps ----
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

# ---- Workspacer startup is registered as an elevated scheduled task ----
$workspacerStartupShortcut = Join-Path (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup') 'workspacer-dotfiles.lnk'
if (Test-Path -LiteralPath $workspacerStartupShortcut) {
    Remove-Item -LiteralPath $workspacerStartupShortcut -Force
}

# ---- PowerToys elevated startup task ----
$powerToysStartupTarget = @(
    'C:\Program Files\PowerToys\PowerToys.exe',
    (Join-Path $env:LOCALAPPDATA 'PowerToys\PowerToys.exe')
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
$powerToysStartupArguments = ''
if (!$powerToysStartupTarget) {
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

$everythingShortcut = Join-Path (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup') 'Everything.lnk'
if (Test-Path -LiteralPath $everythingShortcut) {
    Remove-Item -LiteralPath $everythingShortcut -Force
    Write-Host 'Removed stale Everything startup shortcut'
}

$staleWinShotXShortcut = Join-Path (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup') 'WinShotX.lnk'
if (Test-Path -LiteralPath $staleWinShotXShortcut) {
    Remove-Item -LiteralPath $staleWinShotXShortcut -Force
    Write-Host 'Removed stale WinShotX startup shortcut'
}

# ---- (unchanged) Windows Terminal font ----
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

# ---- (unchanged) PowerShell modules ----
if (Get-Command Install-Module -ErrorAction SilentlyContinue) {
    try {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop | Out-Null
        foreach ($module in @('PSReadLine')) {
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

# ---- (unchanged) PowerShell profile ----
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

        $profileText = Get-Content -LiteralPath $target -Raw
        Set-Content -LiteralPath $target -Value $profileText -Encoding UTF8
        Write-Host "Enabled PowerShell profile: $target"
    }
}
else {
    Write-Warning 'No Microsoft.PowerShell_profile.ps1 was found in the repository.'
}

# ---- (unchanged) Neovim config ----
$nvimSource = Join-Path $repoRoot 'AppData\Local\nvim'
if (Test-Path -LiteralPath $nvimSource) {
    $nvimTarget = Join-Path $env:LOCALAPPDATA 'nvim'
    New-Item -ItemType Directory -Path $nvimTarget -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $nvimSource '*') -Destination $nvimTarget -Recurse -Force
    Write-Host "Installed Neovim configuration: $nvimTarget"
}

$nircmd = Join-Path $repoRoot 'nircmd'
if (Test-Path -LiteralPath $nircmd) {
    Write-Host "NirCmd files found in $nircmd"
}

[Environment]::SetEnvironmentVariable('WORKSPACER_CONFIG', $repoRoot, 'User')
$env:WORKSPACER_CONFIG = $repoRoot

# ============================================================
# FIX 1: Test-WindowsActivation now launches MAS in a *separate* process
#        and does NOT block the outer script.
# FIX 2: Self-elevation uses powershell.exe (always on PATH).
# ============================================================
function Test-WindowsActivation {
    $windowsApplicationId = '55c92734-d682-4d71-983e-d6ec3f16059f'
    $licensedProduct = Get-CimInstance -ClassName SoftwareLicensingProduct -ErrorAction SilentlyContinue |
        Where-Object {
            $_.PSObject.Properties['ApplicationID'] -and
            $_.ApplicationID -eq $windowsApplicationId -and
            $_.PSObject.Properties['LicenseStatus'] -and
            $_.LicenseStatus -eq 1
        } |
        Select-Object -First 1

    if ($licensedProduct) {
        Write-Host 'Windows activation status: licensed.'
        return
    }

    Write-Host 'Windows is not licensed. Launching Microsoft Activation Scripts in a new elevated window...' -ForegroundColor Yellow

    # Build the MAS invocation as a single PowerShell command string.
    # This inner script self-elevates and then runs MAS.
    $masInner = @'
$ErrorActionPreference = 'Stop'
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList @(
        '-NoProfile','-ExecutionPolicy','Bypass','-Command',
        $MyInvocation.MyCommand.ScriptBlock.ToString()
    )
    return
}
Write-Host 'Launching Microsoft Activation Scripts...' -ForegroundColor Cyan
irm https://get.activated.win | iex
'@

    # Launch the inner script in a *separate* powershell.exe process, elevated,
    # non-blocking (no -Wait). The dotfiles bootstrap continues immediately.
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($masInner))
    Start-Process -FilePath 'powershell.exe' `
        -Verb RunAs `
        -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded) `
        -WindowStyle Normal

    Write-Host 'MAS launcher started in a separate elevated window.'
}

Test-WindowsActivation

# ============================================================
# FIX 3: Workspacer is now initialized LAST, as a separate process.
#        The bootstrap script no longer blocks on workspacer.
# ============================================================
if (Test-Path -LiteralPath $workspacerInstaller) {
    Write-Host 'Initializing workspacer (separate process)...'
    Start-Process -FilePath 'powershell.exe' `
        -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$workspacerInstaller`"") `
        -WorkingDirectory $repoRoot `
        -NoNewWindow
    Write-Host 'workspacer installer launched.'
}
else {
    Write-Warning "Workspacer installer not found: $workspacerInstaller"
}

Write-Host 'Dotfiles bootstrap completed.'
