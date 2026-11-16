$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$userId = "$env:USERDOMAIN\$env:USERNAME"
$wscript = Join-Path $env:WINDIR 'System32\wscript.exe'
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
    -MultipleInstances IgnoreNew

$workspacerLauncher = Join-Path $PSScriptRoot 'start-workspacer-hidden.vbs'
$workspacerAction = New-ScheduledTaskAction -Execute $wscript `
    -Argument "`"$workspacerLauncher`"" -WorkingDirectory $repoRoot
$workspacerTrigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
$workspacerPrincipal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName 'Workspacer (elevated)' -Action $workspacerAction `
    -Trigger $workspacerTrigger -Principal $workspacerPrincipal -Settings $settings -Force | Out-Null

$vimExe = Get-ChildItem -LiteralPath (Join-Path $env:LOCALAPPDATA 'Windows-Automation') `
    -Recurse -File -Filter 'vim_ahk.exe' -ErrorAction Stop | Select-Object -First 1
if (!$vimExe) { throw 'vim_ahk.exe was not found.' }
$vimLauncher = Join-Path $PSScriptRoot 'start-vim-ahk.vbs'
$vimAction = New-ScheduledTaskAction -Execute $wscript `
    -Argument "`"$vimLauncher`" `"$($vimExe.FullName)`"" -WorkingDirectory $vimExe.DirectoryName
$vimTrigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
$vimPrincipal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName 'AutoHotkey Vim (Windows-Automation)' -Action $vimAction `
    -Trigger $vimTrigger -Principal $vimPrincipal -Settings $settings -Force | Out-Null

$komorebiLauncher = Join-Path $repoRoot 'komorebi\start-komorebi-hidden.vbs'
$komorebiAction = New-ScheduledTaskAction -Execute $wscript `
    -Argument "`"$komorebiLauncher`"" -WorkingDirectory $repoRoot
$komorebiTrigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
$komorebiPrincipal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName 'komorebi (elevated)' -Action $komorebiAction `
    -Trigger $komorebiTrigger -Principal $komorebiPrincipal -Settings $settings -Force | Out-Null

Get-Process workspacer,workspacer.Watcher,vim_ahk,komorebi,whkd,komorebi-bar -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName 'Workspacer (elevated)' -ErrorAction SilentlyContinue | Out-Null
Start-ScheduledTask -TaskName 'komorebi (elevated)'
Start-ScheduledTask -TaskName 'AutoHotkey Vim (Windows-Automation)'
Write-Host 'Refreshed elevated komorebi and AutoHotkey startup tasks with 3-second launch delays.'
