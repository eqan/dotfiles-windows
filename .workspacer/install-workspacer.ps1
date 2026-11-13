$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$launcher = Join-Path $PSScriptRoot 'start-workspacer-hidden.vbs'
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
if (Test-Path -LiteralPath $startup) {
    Remove-Item -LiteralPath $startup -Force
}

$taskName = 'Workspacer (elevated)'
$userId = "$env:USERDOMAIN\$env:USERNAME"
$taskAction = New-ScheduledTaskAction -Execute (Join-Path $env:WINDIR 'System32\wscript.exe') `
    -Argument "`"$launcher`"" `
    -WorkingDirectory $repoRoot
$taskTrigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
$taskPrincipal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest
$taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
    -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger `
    -Principal $taskPrincipal -Settings $taskSettings -Force | Out-Null

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
    Start-ScheduledTask -TaskName $taskName
}
Write-Host 'Configured elevated startup: Workspacer'
