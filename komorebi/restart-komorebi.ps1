$ErrorActionPreference = 'SilentlyContinue'

# Clear any modifier state left behind by a crashed hotkey client.
if (-not ('KomorebiKeyReset' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class KomorebiKeyReset {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extra);
    public static void Release(byte key) { keybd_event(key, 0, 0x0002, UIntPtr.Zero); }
}
'@
}
[byte[]]$modifiers = 0x10, 0x11, 0x12, 0x5B, 0x5C
foreach ($modifier in $modifiers) { [KomorebiKeyReset]::Release($modifier) }

# The elevated startup task performs the actual cleanup and launch.
Start-ScheduledTask -TaskName 'komorebi (elevated)'
Start-Sleep -Seconds 8

$komorebi = Get-Process komorebi -ErrorAction SilentlyContinue
$whkd = Get-Process whkd -ErrorAction SilentlyContinue
$bar = Get-Process komorebi-bar -ErrorAction SilentlyContinue
if (!$komorebi -or !$whkd -or !$bar) {
    throw 'Komorebi recovery failed: the manager, whkd, or bar did not start.'
}

Write-Host 'Komorebi, whkd, and komorebi-bar recovered successfully.'
