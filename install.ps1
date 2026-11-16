$ErrorActionPreference = 'Stop'

$repoRoot = $PSScriptRoot
$automationRoot = Join-Path $env:LOCALAPPDATA 'Windows-Automation'

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

function Remove-ReplacedApplications {
    $replacedPackages = @(
        'rickbutton.workspacer',
        'AmN.yasb',
        'Microsoft.PowerToys',
        'Flow-Launcher.Flow-Launcher',
        'Brave.Brave',
        'WinShotX.WinShotX'
    )

    foreach ($packageId in $replacedPackages) {
        $installed = (& winget list --id $packageId --exact --source winget `
            --accept-source-agreements 2>$null | Out-String)
        if ($installed -match [regex]::Escape($packageId)) {
            Write-Host "Removing replaced application $packageId..."
            & winget uninstall --id $packageId --exact --source winget --silent `
                --accept-source-agreements
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Could not remove $packageId (exit code $LASTEXITCODE). Run the bootstrap from Administrator PowerShell."
            }
        }
    }

    Get-AppxPackage | Where-Object {
        $_.Name -in @(
            'Microsoft.PowerToys.FileLocksmithContextMenu',
            'Microsoft.PowerToys.ImageResizerContextMenu',
            'Microsoft.PowerToys.PowerRenameContextMenu'
        )
    } | ForEach-Object {
        Remove-AppxPackage -Package $_.PackageFullName -ErrorAction SilentlyContinue
    }

    Unregister-ScheduledTask -TaskName 'PowerToys (elevated)' -Confirm:$false -ErrorAction SilentlyContinue
    $powerToysShortcut = Join-Path (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup') 'PowerToys.lnk'
    if (Test-Path -LiteralPath $powerToysShortcut) {
        Remove-Item -LiteralPath $powerToysShortcut -Force
    }
    foreach ($powerToysKey in @(
        'HKCU:\Software\Microsoft\PowerToys',
        'HKCU:\Software\Classes\AllFileSystemObjects\ShellEx\ContextMenuHandlers\PowerRenameExt',
        'HKCU:\Software\Classes\Directory\Background\shellex\ContextMenuHandlers\PowerRenameExt'
    )) {
        Remove-Item -LiteralPath $powerToysKey -Recurse -Force -ErrorAction SilentlyContinue
    }
    foreach ($powerToysDirectory in @(
        (Join-Path $env:LOCALAPPDATA 'PowerToys'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\PowerToys')
    )) {
        if (Test-Path -LiteralPath $powerToysDirectory) {
            try { [IO.Directory]::Delete($powerToysDirectory, $true) } catch { Write-Warning "Could not remove ${powerToysDirectory}: $($_.Exception.Message)" }
        }
    }
}

Remove-ReplacedApplications

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

function Apply-LightweightWindowsDebloat {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Service and scheduled-task debloat requires an Administrator PowerShell session.'
    }

    # Optional services only. They remain available on demand because Manual is used,
    # rather than permanently disabling the service.
    $optionalServices = @(
        'WSearch',          # Everything/Flow replaces Windows Search indexing
        'Spooler',          # Enable manually when printing is needed
        'LanmanServer',     # Enable manually when sharing files/printers
        'TrkWks',           # Legacy distributed-link tracking
        'IpOverUsbSvc',     # Windows Phone/USB development transport
        'CDPSvc',           # Connected Devices Platform
        'CDPUserSvc',       # Connected Devices per-user service prefix
        'SysMain',          # Optional prefetch/caching service
        'InventorySvc',     # Compatibility appraisal and inventory telemetry
        'whesvc',           # Windows health/usage experience telemetry
        'PcaSvc'            # Program Compatibility Assistant
    )

    foreach ($serviceName in $optionalServices) {
        Get-Service -Name $serviceName -ErrorAction SilentlyContinue |
            ForEach-Object {
                try {
                    Set-Service -Name $_.Name -StartupType Manual -ErrorAction Stop
                    if ($_.Status -eq 'Running') {
                        Stop-Service -Name $_.Name -Force -ErrorAction SilentlyContinue
                    }
                    Write-Host "Set optional service to Manual: $($_.Name)"
                }
                catch {
                    Write-Warning "Could not adjust service $($_.Name): $($_.Exception.Message)"
                }
            }
    }

    # Nonessential telemetry, feedback, Maps, and Xbox maintenance tasks.
    $optionalTasks = @(
        @{ Path = '\Microsoft\Windows\Application Experience\'; Name = 'Microsoft Compatibility Appraiser' },
        @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'Consolidator' },
        @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'UsbCeip' },
        @{ Path = '\Microsoft\Windows\Feedback\Siuf\'; Name = 'DmClient' },
        @{ Path = '\Microsoft\Windows\Feedback\Siuf\'; Name = 'DmClientOnScenarioDownload' },
        @{ Path = '\Microsoft\Windows\Application Experience\'; Name = 'Microsoft Compatibility Appraiser Exp' },
        @{ Path = '\Microsoft\Windows\Flighting\FeatureConfig\'; Name = 'GovernedFeatureUsageProcessing' },
        @{ Path = '\Microsoft\Windows\Flighting\FeatureConfig\'; Name = 'UsageDataFlushing' },
        @{ Path = '\Microsoft\Windows\Flighting\FeatureConfig\'; Name = 'UsageDataReceiver' },
        @{ Path = '\Microsoft\Windows\Flighting\FeatureConfig\'; Name = 'UsageDataReporting' },
        @{ Path = '\Microsoft\Windows\PerformanceTrace\'; Name = 'ShowFeedbackToast' },
        @{ Path = '\Microsoft\Windows\PerformanceTrace\'; Name = 'WhesvcToast' },
        @{ Path = '\Microsoft\Windows\Sustainability\'; Name = 'SustainabilityTelemetry' },
        @{ Path = '\Microsoft\Windows\Maps\'; Name = 'MapsToastTask' },
        @{ Path = '\Microsoft\Windows\Maps\'; Name = 'MapsUpdateTask' },
        @{ Path = '\Microsoft\XblGameSave\'; Name = 'XblGameSaveTask' }
    )

    foreach ($task in $optionalTasks) {
        try {
            if (Get-ScheduledTask -TaskPath $task.Path -TaskName $task.Name -ErrorAction SilentlyContinue) {
                Disable-ScheduledTask -TaskPath $task.Path -TaskName $task.Name -ErrorAction Stop | Out-Null
                Write-Host "Disabled optional task: $($task.Path)$($task.Name)"
            }
        }
        catch {
            Write-Warning "Could not disable task $($task.Path)$($task.Name): $($_.Exception.Message)"
        }
    }
}

function Repair-ClipboardUserService {
    # Ditto complements the Windows clipboard; it does not replace the
    # clipboard service. The per-user instances are trigger-started by
    # Windows, so do not try to start them directly (that is denied even from
    # some elevated sessions). Repair only the service template if a previous
    # debloat pass disabled it.
    $clipboardTemplate = 'HKLM:\SYSTEM\CurrentControlSet\Services\cbdhsvc'
    $template = Get-ItemProperty -LiteralPath $clipboardTemplate -ErrorAction SilentlyContinue
    if ($template -and $template.Start -eq 4) {
        Set-ItemProperty -LiteralPath $clipboardTemplate -Name Start -Type DWord -Value 3
        Write-Host 'Restored the Windows Clipboard User Service template to Manual.'
    }
    else {
        Write-Host 'Windows Clipboard User Service remains available (trigger-started/manual).'
    }
}

Repair-ClipboardUserService

Apply-LightweightWindowsDebloat

function Remove-ReplacedWindowsScreenshotApp {
    $snippingTool = Get-AppxPackage -Name Microsoft.ScreenSketch -ErrorAction SilentlyContinue
    if ($snippingTool) {
        foreach ($package in @($snippingTool)) {
            Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
        }
        Write-Host 'Removed the native Snipping Tool; Flameshot is the screenshot replacement.'
    }
    else {
        Write-Host 'Native Snipping Tool is already removed for this user.'
    }
}

Remove-ReplacedWindowsScreenshotApp

function Remove-ReplacedWindowsPhotosApp {
    $photoPackages = @(
        'Microsoft.Windows.Photos',
        'Microsoft.Photos.MediaEngineDLC',
        'Microsoft.Windows.Photos.Automation'
    )

    $removedAny = $false
    foreach ($packageName in $photoPackages) {
        $packages = @(Get-AppxPackage -Name $packageName -ErrorAction SilentlyContinue)
        foreach ($package in $packages) {
            try {
                Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
                $removedAny = $true
                Write-Host "Removed Windows Photos package $($package.Name)."
            }
            catch {
                Write-Warning "Could not remove $($package.Name): $($_.Exception.Message)"
            }
        }
    }

    if (!$removedAny) {
        Write-Host 'Native Windows Photos is already removed for this user.'
    }
}

Remove-ReplacedWindowsPhotosApp

function Remove-ReplacedWindowsTerminal {
    $windowsTerminal = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue
    if ($windowsTerminal) {
        foreach ($package in @($windowsTerminal)) {
            Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
        }
        Write-Host 'Removed native Windows Terminal; WezTerm is the configured terminal.'
    }
    else {
        Write-Host 'Native Windows Terminal is already removed for this user.'
    }
}

Remove-ReplacedWindowsTerminal

# ---- package installation ----
$packages = @(
    'Microsoft.PowerShell',
    'Neovim.Neovim',
    'voidtools.Everything',
    'Ditto.Ditto',
    'LGUG2Z.komorebi',
    'LGUG2Z.whkd',
    'Flameshot.Flameshot',
    'DuongDieuPhap.ImageGlass',
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

function Install-CodexCli {
    $npm = Get-Command npm.exe -ErrorAction SilentlyContinue
    if (!$npm) {
        Write-Warning 'Skipping OpenAI Codex CLI because npm is not available.'
        return
    }

    $npmPrefix = (& npm.exe prefix --global 2>$null | Select-Object -Last 1).Trim()
    if (!$npmPrefix) {
        throw 'Could not determine the npm global prefix for OpenAI Codex CLI.'
    }

    Write-Host 'Installing or updating OpenAI Codex CLI...'
    & npm.exe install --global '@openai/codex@latest'
    if ($LASTEXITCODE -ne 0) {
        throw "OpenAI Codex CLI installation failed with exit code $LASTEXITCODE."
    }

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $pathParts = @($userPath -split ';' | Where-Object { $_ })
    if ($pathParts -notcontains $npmPrefix) {
        [Environment]::SetEnvironmentVariable('Path', (($pathParts + $npmPrefix) -join ';'), 'User')
    }
    $env:Path = "$npmPrefix;$env:Path"

    $codex = Get-Command codex.exe -ErrorAction SilentlyContinue
    if (!$codex) {
        throw 'OpenAI Codex CLI installed, but codex.exe was not found on PATH.'
    }
    Write-Host "OpenAI Codex CLI ready: $(& codex.exe --version)"
}

Install-CodexCli

function Install-Keypirinha {
    $keypirinhaRoot = Join-Path $env:LOCALAPPDATA 'Keypirinha'
    $keypirinhaExe = Join-Path $keypirinhaRoot 'keypirinha.exe'
    if (Test-Path -LiteralPath $keypirinhaExe) {
        Write-Host 'Skipping Keypirinha (already installed).'
        return
    }
    $archive = Join-Path $env:TEMP 'keypirinha-2.26-x64-portable.7z'
    $url = 'https://github.com/Keypirinha/Keypirinha/releases/download/v2.26/keypirinha-2.26-x64-portable.7z'
    $sevenZip = 'C:\Program Files\7-Zip\7z.exe'
    if (!(Test-Path -LiteralPath $sevenZip)) { throw '7-Zip is required to install Keypirinha.' }
    Write-Host 'Installing Keypirinha from the official portable release...'
    Invoke-WebRequest -Uri $url -OutFile $archive
    New-Item -ItemType Directory -Path $env:LOCALAPPDATA -Force | Out-Null
    & $sevenZip x $archive "-o$env:LOCALAPPDATA" -y | Out-Null
    if (!(Test-Path -LiteralPath $keypirinhaExe)) { throw 'Keypirinha extraction did not produce keypirinha.exe.' }
}

Install-Keypirinha

function Install-KeypirinhaSystemActions {
    $userPackages = Join-Path $env:LOCALAPPDATA 'Keypirinha\portable\Profile\InstalledPackages'
    $source = Join-Path $repoRoot 'keypirinha\systemactions.py'
    if (!(Test-Path -LiteralPath $source)) { throw 'Keypirinha system-actions plugin source was not found.' }
    New-Item -ItemType Directory -Path $userPackages -Force | Out-Null
    $packageZip = Join-Path $env:TEMP 'SystemActions.keypirinha-package.zip'
    $packageDest = Join-Path $userPackages 'SystemActions.keypirinha-package'
    Compress-Archive -LiteralPath $source -DestinationPath $packageZip -Force
    Move-Item -LiteralPath $packageZip -Destination $packageDest -Force
    Write-Host 'Configured the native Keypirinha system-actions overlay.'
}

Install-KeypirinhaSystemActions

# komorebi's native bar replaces YASB; remove an older YASB installation if present.
if ((winget list --id AmN.yasb --exact --source winget --accept-source-agreements 2>$null | Out-String) -match 'AmN\.yasb') {
    Write-Host 'Removing redundant YASB; komorebi-bar provides the status bar with fewer components.'
    & winget uninstall --id AmN.yasb --exact --source winget --silent --accept-source-agreements
}

# ---- lightweight komorebi window-manager configuration ----
function Install-KomorebiConfiguration {
    $komorebiSource = Join-Path $repoRoot 'komorebi'
    $komorebiTarget = Join-Path $env:USERPROFILE 'komorebi.json'
    $barTarget = Join-Path $env:USERPROFILE 'komorebi.bar.json'
    $applicationsTarget = Join-Path $env:USERPROFILE 'applications.json'
    $whkdDirectory = Join-Path $env:USERPROFILE '.config'
    $whkdTarget = Join-Path $whkdDirectory 'whkdrc'
    $quickstart = 'C:\Program Files\komorebi\bin\komorebic.exe'

    New-Item -ItemType Directory -Path $whkdDirectory -Force | Out-Null
    if (!(Test-Path -LiteralPath $applicationsTarget) -and (Test-Path -LiteralPath $quickstart)) {
        & $quickstart quickstart | Out-Null
    }
    Copy-Item -LiteralPath (Join-Path $komorebiSource 'komorebi.json') -Destination $komorebiTarget -Force
    Copy-Item -LiteralPath (Join-Path $komorebiSource 'komorebi.bar.json') -Destination $barTarget -Force
    Copy-Item -LiteralPath (Join-Path $komorebiSource 'whkdrc') -Destination $whkdTarget -Force
    if (Test-Path -LiteralPath $applicationsTarget) {
        $applications = Get-Content -Raw -LiteralPath $applicationsTarget | ConvertFrom-Json
        $vimAkhRule = [pscustomobject]@{
            ignore = @([pscustomobject]@{
                kind = 'Exe'
                id = 'vim_ahk.exe'
                matching_strategy = 'Equals'
            })
        }
        $applications | Add-Member -MemberType NoteProperty -Name 'Vim AHK system menu' `
            -Value $vimAkhRule -Force
        $applications | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $applicationsTarget -Encoding UTF8
    }
    Write-Host "Configured komorebi, built-in bar, and whkd under $env:USERPROFILE."
}

Install-KomorebiConfiguration

function Set-WindowsTaskbarAutoHide {
    $taskbarKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
    if (!(Test-Path -LiteralPath $taskbarKey)) {
        Write-Warning 'Windows taskbar layout key was not found; leaving taskbar settings unchanged.'
        return
    }
    $settings = (Get-ItemProperty -LiteralPath $taskbarKey -Name Settings).Settings
    $settings[8] = 3
    Set-ItemProperty -LiteralPath $taskbarKey -Name Settings -Value $settings
    Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer.exe
    Write-Host 'Configured the Windows taskbar to persistent auto-hide; komorebi-bar remains visible.'
}

Set-WindowsTaskbarAutoHide

function Set-DesktopIconsHidden {
    $desktopKey = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    & reg.exe add $desktopKey /v HideIcons /t REG_DWORD /d 1 /f | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not hide desktop icons through the current-user registry.'
    }
    Write-Host 'Configured desktop icons to stay hidden; Ctrl+Alt+D toggles them in Vim AHK.'
}

Set-DesktopIconsHidden

if (Test-Path -LiteralPath (Join-Path $repoRoot 'komorebi\restart-komorebi.ps1')) {
    Write-Host 'Installed Komorebi recovery script: komorebi\restart-komorebi.ps1'
}

# ---- lightweight Spotlight-style Keypirinha configuration ----
$keypirinhaRoot = Join-Path $env:LOCALAPPDATA 'Keypirinha'
$keypirinhaExe = Join-Path $keypirinhaRoot 'keypirinha.exe'
$keypirinhaUser = Join-Path $keypirinhaRoot 'portable\Profile\User'
$keypirinhaConfig = Join-Path $repoRoot 'keypirinha\Keypirinha.ini'
if (Test-Path -LiteralPath $keypirinhaExe) {
    New-Item -ItemType Directory -Path $keypirinhaUser -Force | Out-Null
    if (Test-Path -LiteralPath $keypirinhaConfig) {
        Copy-Item -LiteralPath $keypirinhaConfig -Destination (Join-Path $keypirinhaUser 'Keypirinha.ini') -Force
    }
    $keypirinhaRunKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    New-Item -Path $keypirinhaRunKey -Force | Out-Null
    Set-ItemProperty -Path $keypirinhaRunKey -Name Keypirinha -Value ('"' + $keypirinhaExe + '"')
    if (Get-ScheduledTask -TaskName 'Flow.Launcher Startup' -ErrorAction SilentlyContinue) {
        Disable-ScheduledTask -TaskName 'Flow.Launcher Startup' -ErrorAction SilentlyContinue | Out-Null
    }
    Get-Process Flow.Launcher,Flow -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $env:LOCALAPPDATA 'FlowLauncher') -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $env:APPDATA 'FlowLauncher') -Recurse -Force -ErrorAction SilentlyContinue
    if (!(Get-Process keypirinha -ErrorAction SilentlyContinue)) {
        Start-Process -FilePath $keypirinhaExe -WorkingDirectory $keypirinhaRoot
    }
    Write-Host 'Configured Keypirinha as the lightweight Spotlight-style Win+S search overlay; Everything is provided by its built-in plugin.'
}
else {
    Write-Warning 'Keypirinha was not found under LocalAppData; install the official portable release before running the launcher setup.'
}

# ---- lightweight screenshot capture ----
$flameshotExe = 'C:\Program Files\Flameshot\bin\flameshot.exe'
$captureTaskName = 'Flameshot capture (Ditto bridge)'
Unregister-ScheduledTask -TaskName $captureTaskName -Confirm:$false -ErrorAction SilentlyContinue
# The shortcut invokes the already-running Flameshot daemon directly. Do not
# register a logon task here: it adds a hidden VBScript/PowerShell process and
# can start an unwanted capture session during sign-in.
if (Test-Path -LiteralPath $flameshotExe) {
    Get-Process flameshot -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    $startupRunKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    New-Item -Path $startupRunKey -Force | Out-Null
    Set-ItemProperty -Path $startupRunKey -Name Flameshot -Value ('"' + $flameshotExe + '"')
    Remove-ItemProperty -Path $startupRunKey -Name Greenshot -ErrorAction SilentlyContinue
    Start-Process -FilePath $flameshotExe
    Write-Host 'Configured lightweight Flameshot capture-to-clipboard on Win+Shift+S and startup.'
}
else {
    Write-Warning 'Flameshot was not found after installation; screenshot replacement was skipped.'
}

function Get-ImageGlassExecutable {
    $candidates = @(
        'C:\Program Files\ImageGlass\ImageGlass.exe',
        (Join-Path $env:LOCALAPPDATA 'Programs\ImageGlass\ImageGlass.exe')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    $fromPath = (Get-Command ImageGlass.exe -ErrorAction SilentlyContinue).Source
    if ($fromPath) {
        return $fromPath
    }

    $appx = Get-AppxPackage -Name '*ImageGlass*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($appx) {
        $appxExe = Join-Path $appx.InstallLocation 'ImageGlass.exe'
        if (Test-Path -LiteralPath $appxExe) {
            return $appxExe
        }
    }

    return $null
}

function Install-ImageGlassThemeAndConfig {
    $configDir = Join-Path $env:LOCALAPPDATA 'ImageGlass'
    $themesDir = Join-Path $configDir '_themes'
    $themeFolderName = 'WinUI3-Dark.Mizan'
    $themeDir = Join-Path $themesDir $themeFolderName
    $themeUrl = 'https://github.com/mizanti/ImageGlass-WinUI3-Theme/releases/download/v1.1/WinUI3-Dark.Mizan.igtheme'
    $configSource = Join-Path $repoRoot 'imageglass\igconfig.json'
    $configTarget = Join-Path $configDir 'igconfig.json'

    New-Item -ItemType Directory -Path $themesDir -Force | Out-Null

    try {
        $archive = Join-Path $env:TEMP 'WinUI3-Dark.Mizan.igtheme.zip'
        Write-Host 'Installing ImageGlass WinUI3 Dark theme...'
        Invoke-WebRequest -Uri $themeUrl -OutFile $archive
        $staging = Join-Path $env:TEMP ('ig-theme-' + [guid]::NewGuid().ToString('N'))
        Expand-Archive -LiteralPath $archive -DestinationPath $staging -Force
        $themeJson = Get-ChildItem -LiteralPath $staging -Filter 'igtheme.json' -Recurse |
            Select-Object -First 1
        if (!$themeJson) {
            throw 'The WinUI3 Dark theme archive did not contain igtheme.json.'
        }

        # ImageGlass 10 rejects v9 packs. Bump only the spec version so icons stay intact.
        $themeJsonText = Get-Content -Raw -LiteralPath $themeJson.FullName
        $themeJsonText = [regex]::Replace(
            $themeJsonText,
            '"Version"\s*:\s*"9\.0"',
            '"Version": 10',
            1
        )
        Set-Content -LiteralPath $themeJson.FullName -Value $themeJsonText -Encoding UTF8

        if (Test-Path -LiteralPath $themeDir) {
            Remove-Item -LiteralPath $themeDir -Recurse -Force
        }
        Copy-Item -LiteralPath $themeJson.Directory.FullName -Destination $themeDir -Recurse
        Write-Host "Installed ImageGlass theme pack: $themeFolderName"
    }
    catch {
        Write-Warning "Could not install the ImageGlass WinUI3 Dark theme: $($_.Exception.Message)"
    }

    if (Test-Path -LiteralPath $configSource) {
        Copy-Item -LiteralPath $configSource -Destination $configTarget -Force
        Write-Host "Configured ImageGlass with WinUI3 Dark and Mica: $configTarget"
    }

    $imageGlassExe = Get-ImageGlassExecutable
    if ($imageGlassExe) {
        & $imageGlassExe --ig-set-default-viewer --ig-no-quick-setup
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            Write-Warning "ImageGlass could not register as the default viewer (exit code $LASTEXITCODE)."
        }
        else {
            Write-Host 'Registered ImageGlass as the default photo viewer.'
        }
    }
    else {
        Write-Warning 'ImageGlass was not found after installation; viewer configuration was skipped.'
    }
}

Install-ImageGlassThemeAndConfig

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
        $updatedCustomText = [regex]::Replace(
            $updatedCustomText,
            '(?ms); Open (?:Flow Launcher|Keypirinha).*?\r?\n#s::\r?\n\s*(?:Send, \^!s|Run, .*?--show,, Hide)\r?\nReturn',
            '; Open Keypirinha directly; its built-in Everything package provides fast file search.' + [Environment]::NewLine +
            '#s::' + [Environment]::NewLine +
            '  Run, "C:\Users\eqan\AppData\Local\Keypirinha\keypirinha.exe" --show,, Hide' + [Environment]::NewLine +
            'Return')
        if ($updatedCustomText -notmatch '(?m)^#s::\s*$') {
            $updatedCustomText = '; Open Keypirinha directly; its built-in Everything package provides fast file search.' +
                [Environment]::NewLine + '#s::' + [Environment]::NewLine +
                '  Run, "C:\Users\eqan\AppData\Local\Keypirinha\keypirinha.exe" --show,, Hide' + [Environment]::NewLine + 'Return' +
                [Environment]::NewLine + [Environment]::NewLine + $updatedCustomText
        }
        $flameshotBinding = '; Launch the already-running Flameshot daemon directly.' +
            [Environment]::NewLine + '#+s::' + [Environment]::NewLine +
            '  Run, "C:\Program Files\Flameshot\bin\flameshot.exe" gui --clipboard,, Hide' + [Environment]::NewLine +
            'Return'
        $updatedCustomText = [regex]::Replace($updatedCustomText, '(?ms); Replace Windows Snipping Tool.*?^#\+s::\s*\r?\n.*?^Return\s*\r?\n\r?\n?', '')
        $updatedCustomText = [regex]::Replace($updatedCustomText, '(?ms)^#\+s::\s*\r?\n.*?^Return\s*\r?\n\r?\n?', '')
        $updatedCustomText = $flameshotBinding + [Environment]::NewLine + [Environment]::NewLine + $updatedCustomText
        if ($updatedCustomText -notmatch '(?m)^\^!d::\s*$') {
            $desktopToggle = '; Toggle desktop icons: hidden by default, reveal temporarily when needed.' +
                [Environment]::NewLine + '^!d::' + [Environment]::NewLine +
                '  RegRead, HideIcons, HKCU, Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced, HideIcons' +
                [Environment]::NewLine +
                '  if (HideIcons = 1)' + [Environment]::NewLine +
                '    RegWrite, REG_DWORD, HKCU, Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced, HideIcons, 0' +
                [Environment]::NewLine +
                '  else' + [Environment]::NewLine +
                '    RegWrite, REG_DWORD, HKCU, Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced, HideIcons, 1' +
                [Environment]::NewLine +
                '  DllCall("Shell32\SHChangeNotify", "UInt", 0x08000000, "UInt", 0, "Ptr", 0, "Ptr", 0)' +
                [Environment]::NewLine + 'Return' + [Environment]::NewLine + [Environment]::NewLine
            $updatedCustomText = $desktopToggle + $updatedCustomText
        }
        $updatedCustomText = $updatedCustomText -replace '(?ms); Close the focused komorebi window\.\r?\n!c::\r?\n\s*Run, "C:\\Program Files\\komorebi\\bin\\komorebic\.exe" close,, Hide\r?\nReturn\r?\n\r?\n', ''
        if ($updatedCustomText -notmatch '(?m)^#MenuMaskKey\s+') {
            # vkFF is documented as "no mapping" and avoids vk07, which newer Windows versions reserve.
            $updatedCustomText = '#MenuMaskKey vkFF' + [Environment]::NewLine + [Environment]::NewLine + $updatedCustomText
        }
        if ($updatedCustomText -notmatch '(?m)^; Keypirinha system power palette$') {
            $systemMenu = @'
; Keypirinha system power palette (Alt+P; search namespace: power:)
!p::
  Run, "C:\Users\eqan\AppData\Local\Keypirinha\keypirinha.exe" --show,, Hide
  Sleep, 80
  SendInput, ^a{Backspace}power:
Return

'@
            $updatedCustomText = $systemMenu + $updatedCustomText
        }
        $dittoBinding = '; Open Ditto clipboard history through its supported single-instance command.' +
            [Environment]::NewLine + '^+h::' + [Environment]::NewLine +
            '  Run, "C:\Program Files\Ditto\Ditto.exe" -open,, Hide' + [Environment]::NewLine +
            'Return'
        if ($updatedCustomText -match '(?ms); Open Ditto clipboard history.*?^\^\+h::\s*\r?\n.*?^Return\s*$') {
            $updatedCustomText = [regex]::Replace($updatedCustomText, '(?ms); Open Ditto clipboard history.*?^\^\+h::\s*\r?\n.*?^Return\s*$', $dittoBinding, 1)
        }
        elseif ($updatedCustomText -match '(?m)^\^\+h::\s*$') {
            $updatedCustomText = [regex]::Replace($updatedCustomText, '(?ms)^\^\+h::\s*\r?\n.*?^Return\s*$', $dittoBinding, 1)
        }
        else {
            $updatedCustomText = $dittoBinding + [Environment]::NewLine + [Environment]::NewLine + $updatedCustomText
        }
        $updatedCustomText = $updatedCustomText -replace '(?ms); Close the Start/menu overlay for a standalone Win press without intercepting Win\+key combinations\.?\r?\n~LWin Up::.*?Return\r?\n\r?\n~RWin Up::.*?Return\r?\n\r?\n', ''
        $updatedCustomText = $updatedCustomText -replace '(?ms); Function to Call the live draw\r?\n#o::\r?\n\s*Run,"C:\\Program Files\\workspacer\\workspacer\.exe"\r?\nreturn', '; Start komorebi and its built-in bar without opening a console window.' + [Environment]::NewLine + '#o::' + [Environment]::NewLine + '  Run, "C:\\Program Files\\komorebi\\bin\\komorebic.exe" start --whkd --bar,, Hide' + [Environment]::NewLine + 'return'
        $updatedCustomText = $updatedCustomText -replace '(?ms); (?:Start|Restart) komorebi.*?\r?\n#o::\r?\n\s*Run, "C:\\Program Files\\komorebi\\bin\\komorebic\.exe" start --whkd --bar,, Hide\r?\nreturn', '; Restart the complete elevated Komorebi stack without opening a console window.' + [Environment]::NewLine + '#o::' + [Environment]::NewLine + '  Run, powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\\Users\\eqan\\.config\\dotfiles-windows\\komorebi\\restart-komorebi.ps1", , Hide' + [Environment]::NewLine + 'return'
        if ($false) {
            $standaloneWinMask = '; Suppress Start for a standalone Win press while preserving Win+key shortcuts.' +
                [Environment]::NewLine + '; The original Win events are blocked, then re-emitted so Workspacer still' +
                [Environment]::NewLine + '; receives the modifier. vkFF is a harmless "no mapping" key-up mask.' +
                [Environment]::NewLine + 'LWin::' + [Environment]::NewLine +
                '  Send, {LWin Down}' + [Environment]::NewLine + 'Return' +
                [Environment]::NewLine + [Environment]::NewLine + 'LWin Up::' +
                [Environment]::NewLine + '  Send, {Blind}{vkFF}{LWin Up}' + [Environment]::NewLine + 'Return' +
                [Environment]::NewLine + [Environment]::NewLine + 'RWin::' +
                [Environment]::NewLine + '  Send, {RWin Down}' + [Environment]::NewLine + 'Return' +
                [Environment]::NewLine + [Environment]::NewLine + 'RWin Up::' +
                [Environment]::NewLine + '  Send, {Blind}{vkFF}{RWin Up}' + [Environment]::NewLine + 'Return' +
                [Environment]::NewLine + [Environment]::NewLine
            $updatedCustomText = $standaloneWinMask + $updatedCustomText
        }
        if ($false) {
            $workspacerWinMask = '; Re-emit Workspacer''s Win combinations explicitly so Windows never treats' +
                [Environment]::NewLine + '; the synthetic modifier sequence as a request to open Start.' +
                [Environment]::NewLine + '#h::Send, {Blind}{LWin Down}h{LWin Up}' +
                [Environment]::NewLine + '#l::Send, {Blind}{LWin Down}l{LWin Up}' +
                [Environment]::NewLine + '#j::Send, {Blind}{LWin Down}j{LWin Up}' +
                [Environment]::NewLine + '#k::Send, {Blind}{LWin Down}k{LWin Up}' +
                [Environment]::NewLine + '#Space::Send, {Blind}{LWin Down}{Space}{LWin Up}' +
                [Environment]::NewLine + '#Enter::Send, {Blind}{LWin Down}{Enter}{LWin Up}' +
                [Environment]::NewLine + '#q::Send, {Blind}{LWin Down}q{LWin Up}' +
                [Environment]::NewLine + '#Escape::Send, {Blind}{LWin Down}{Escape}{LWin Up}' +
                [Environment]::NewLine + '#n::Send, {Blind}{LWin Down}n{LWin Up}' +
                [Environment]::NewLine + '#c::Send, {Blind}{LWin Down}c{LWin Up}'
            for ($i = 1; $i -le 9; $i++) {
                $workspacerWinMask += [Environment]::NewLine + "#$i::Send, {Blind}{LWin Down}$i{LWin Up}"
            }
            $workspacerWinMask += [Environment]::NewLine + '#+h::Send, {Blind}{LWin Down}{LShift Down}h{LShift Up}{LWin Up}' +
                [Environment]::NewLine + '#+l::Send, {Blind}{LWin Down}{LShift Down}l{LShift Up}{LWin Up}' +
                [Environment]::NewLine + '#+Space::Send, {Blind}{LWin Down}{LShift Down}{Space}{LShift Up}{LWin Up}'
            for ($i = 1; $i -le 9; $i++) {
                $workspacerWinMask += [Environment]::NewLine + "#+$i::Send, {Blind}{LWin Down}{LShift Down}$i{LShift Up}{LWin Up}"
            }
            $updatedCustomText = $workspacerWinMask + [Environment]::NewLine + [Environment]::NewLine + $updatedCustomText
        }
        $updatedCustomText = $updatedCustomText -replace '(?ms); Prevent the Start/menu popup while preserving the physical Win modifier\.\r?\n; VKE8 is an unused virtual key; Windows sees a modifier combination instead\r?\n; of treating a standalone Win press as a request to open Start\.\r?\n~LWin::.*?Return\r?\n\r?\n~RWin::.*?Return\r?\n\r?\n', ''
        $updatedCustomText = $updatedCustomText -replace '(?ms); Close the Start/menu overlay for a standalone Win press without intercepting Win\+key combinations used by Workspacer\.\r?\n~LWin Up::.*?Return\r?\n\r?\n~RWin Up::.*?Return\r?\n\r?\n', ''
        # These two legacy AHK bindings conflict with Workspacer's Win+H/Win+J.
        $updatedCustomText = $updatedCustomText -replace '(?m)^#h::\s*$', '!h::'
        $updatedCustomText = $updatedCustomText -replace '(?m)^#j::\s*$', '!j::'
        $updatedCustomText = $updatedCustomText -replace '(?ms); Suppress standalone Windows-key presses while preserving Win\+key shortcuts\.\r?\n\$LWin::\r?\n\s*KeyWait, LWin\r?\nReturn\r?\n\r?\n\$RWin::\r?\n\s*KeyWait, RWin\r?\nReturn\r?\n\r?\n', ''
        if ($updatedCustomText -ne $customText) {
            Set-Content -LiteralPath $customCommands -Value $updatedCustomText -Encoding UTF8
            Write-Host 'Configured AutoHotkey Win+X for WezTerm and Win+S for Keypirinha.'
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

    # Stop the elevated instance before rebuilding; otherwise vim_ahk.exe is locked
    # and AutoHotkey silently leaves the previous binary running.
    Stop-ScheduledTask -TaskName 'AutoHotkey Vim (Windows-Automation)' -ErrorAction SilentlyContinue
    Get-Process vim_ahk -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue

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

function Install-FlameshotHelperScripts {
    $helperScripts = @(
        'tools\clipboard-image-bridge.ps1',
        'tools\flameshot-capture.ps1',
        'tools\run-flameshot-capture-hidden.vbs'
    )
    foreach ($relativePath in $helperScripts) {
        $source = Join-Path $repoRoot $relativePath
        if (!(Test-Path -LiteralPath $source)) {
            continue
        }
        $target = Join-Path $automationRoot $relativePath
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
}

Install-FlameshotHelperScripts

# ---- Workspacer startup is registered as an elevated scheduled task ----
$workspacerStartupShortcut = Join-Path (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup') 'workspacer-dotfiles.lnk'
if (Test-Path -LiteralPath $workspacerStartupShortcut) {
    Remove-Item -LiteralPath $workspacerStartupShortcut -Force
}

$everythingShortcut = Join-Path (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup') 'Everything.lnk'
if (Test-Path -LiteralPath $everythingShortcut) {
    Remove-Item -LiteralPath $everythingShortcut -Force
    Write-Host 'Removed stale Everything startup shortcut'
}

function Configure-BackgroundUtilities {
    $startupDirectory = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
    $everythingExe = 'C:\Program Files\Everything\Everything.exe'
    $dittoExe = 'C:\Program Files\Ditto\Ditto.exe'
    $userId = "$env:USERDOMAIN\$env:USERNAME"
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable -MultipleInstances IgnoreNew

    foreach ($taskName in @('Everything (background)', 'Ditto (background)')) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    }

    if (Test-Path -LiteralPath $everythingExe) {
        $action = New-ScheduledTaskAction -Execute $everythingExe -Argument '-startup' `
            -WorkingDirectory (Split-Path -Parent $everythingExe)
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
        $principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Limited
        Register-ScheduledTask -TaskName 'Everything (background)' -Action $action -Trigger $trigger `
            -Principal $principal -Settings $settings -Force | Out-Null
        Get-Process Everything -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-ScheduledTask -TaskName 'Everything (background)'
        Write-Host 'Configured Everything to start in the background with -startup.'
    }

    if (Test-Path -LiteralPath $dittoExe) {
        # Ditto stores hotkeys as LOWORD=virtual key and HIWORD=HOTKEYF flags.
        # H (0x48) + Ctrl (0x02) + Shift (0x04) => 0x0648 = 1608.
        $dittoRegistry = 'HKCU:\Software\Ditto'
        New-Item -Path $dittoRegistry -Force | Out-Null
        Set-ItemProperty -Path $dittoRegistry -Name DittoHotKey -Type DWord -Value 1608
        Set-ItemProperty -Path $dittoRegistry -Name DittoHotKey2 -Type DWord -Value 0
        Set-ItemProperty -Path $dittoRegistry -Name DittoHotKey3 -Type DWord -Value 0
        # Let Ditto accept Flameshot's valid bitmap even when its private
        # Clipboard Viewer Ignore marker is also present. This removes the
        # per-capture Task Scheduler/VBScript/PowerShell bridge.
        Set-ItemProperty -Path $dittoRegistry -Name EnforceClipboardIgnoreFormats -Type DWord -Value 0
        $action = New-ScheduledTaskAction -Execute $dittoExe -WorkingDirectory (Split-Path -Parent $dittoExe)
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
        $principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Limited
        Register-ScheduledTask -TaskName 'Ditto (background)' -Action $action -Trigger $trigger `
            -Principal $principal -Settings $settings -Force | Out-Null
        # Ask Ditto to exit cleanly so it clears its saved main HWND. A forced
        # kill leaves a stale HWND behind and makes the next -open request a no-op.
        Start-Process -FilePath $dittoExe -ArgumentList '-exit' -WindowStyle Hidden -ErrorAction SilentlyContinue
        $dittoDeadline = (Get-Date).AddSeconds(3)
        while ((Get-Process Ditto -ErrorAction SilentlyContinue) -and (Get-Date) -lt $dittoDeadline) {
            Start-Sleep -Milliseconds 100
        }
        Get-Process Ditto -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-ScheduledTask -TaskName 'Ditto (background)'
        Write-Host 'Configured Ditto to start in the background.'
    }
}

Configure-BackgroundUtilities

$staleWinShotXShortcut = Join-Path (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup') 'WinShotX.lnk'
if (Test-Path -LiteralPath $staleWinShotXShortcut) {
    Remove-Item -LiteralPath $staleWinShotXShortcut -Force
    Write-Host 'Removed stale WinShotX startup shortcut'
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

# ---- lf file manager configuration ----
$lfSource = Join-Path $repoRoot '.config\lf'
if (Test-Path -LiteralPath $lfSource) {
    $lfTarget = Join-Path $env:APPDATA 'lf'
    New-Item -ItemType Directory -Path $lfTarget -Force | Out-Null
    Copy-Item -Path (Join-Path $lfSource '*') -Destination $lfTarget -Recurse -Force
    Write-Host "Installed ranger-style lf configuration: $lfTarget"
}
else {
    Write-Warning 'No lf configuration directory was found in the repository.'
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
# Komorebi is initialized last as an elevated scheduled task.
# The legacy Workspacer task is disabled and removed from startup.
# ============================================================
function Configure-KomorebiStartup {
    $komorebiLauncher = Join-Path $repoRoot 'komorebi\start-komorebi-hidden.vbs'
    $komorebiExe = 'C:\Program Files\komorebi\bin\komorebic.exe'
    $whkdExe = 'C:\Program Files\whkd\bin\whkd.exe'
    if (!(Test-Path -LiteralPath $komorebiLauncher) -or !(Test-Path -LiteralPath $komorebiExe)) {
        throw 'Komorebi startup files were not found after installation.'
    }

    $legacyStartup = Join-Path (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup') 'workspacer-dotfiles.lnk'
    Remove-Item -LiteralPath $legacyStartup -Force -ErrorAction SilentlyContinue
    Disable-ScheduledTask -TaskName 'Workspacer (elevated)' -ErrorAction SilentlyContinue | Out-Null
    Unregister-ScheduledTask -TaskName 'Workspacer (elevated)' -Confirm:$false -ErrorAction SilentlyContinue

    $userId = "$env:USERDOMAIN\$env:USERNAME"
    $wscript = Join-Path $env:WINDIR 'System32\wscript.exe'
    $action = New-ScheduledTaskAction -Execute $wscript `
        -Argument "`"$komorebiLauncher`"" -WorkingDirectory $repoRoot
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
    $principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
        -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName 'komorebi (elevated)' -Action $action -Trigger $trigger `
        -Principal $principal -Settings $settings -Force | Out-Null

    Get-Process komorebi,komorebi-bar,whkd -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-ScheduledTask -TaskName 'komorebi (elevated)'
    Write-Host 'Configured elevated Komorebi startup; current whkdrc bindings will be loaded.'
}

Configure-KomorebiStartup

Write-Host 'Dotfiles bootstrap completed.'
