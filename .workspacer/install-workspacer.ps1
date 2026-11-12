$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$launcher = Join-Path $repoRoot '.workspacer\start-workspacer.cmd'
$exe = 'C:\Program Files\workspacer\workspacer.exe'

$installed = (& winget list --id rickbutton.workspacer --exact --source winget `
    --accept-source-agreements 2>$null | Out-String)
if ($installed -match 'rickbutton\.workspacer') {
    Write-Host 'Skipping Workspacer (already installed).'
}
else {
    Write-Host 'Installing Workspacer with WinGet...'
    winget install --id rickbutton.workspacer --exact --source winget `
        --accept-source-agreements --accept-package-agreements
}

if (!(Test-Path -LiteralPath $exe)) {
    throw "Workspacer was not found at $exe after installation. Restart PowerShell and run this script again."
}

$startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\workspacer-dotfiles.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($startup)
$shortcut.TargetPath = $launcher
$shortcut.WorkingDirectory = $repoRoot
$shortcut.Description = 'Start Workspacer from the dotfiles repository'
$shortcut.Save()

$repair = 'C:\Users\eqan\.workspacer\repair-workspacer-dotfiles.ps1'
if (Test-Path -LiteralPath $repair) {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $repair
}

try {
    $running = Get-Process workspacer -ErrorAction SilentlyContinue
    if ($running) {
        Stop-Process -InputObject $running -Force -ErrorAction Stop
    }
}
catch {
    Write-Warning "Could not restart the existing Workspacer process. Close it from the tray or press Alt+Shift+Q, then run setup again."
}

if (!(Get-Process workspacer -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $launcher -WorkingDirectory $repoRoot
}
Write-Host 'Workspacer setup complete.'
