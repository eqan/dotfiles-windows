<#
Capture a Flameshot region and publish only the newly-created image.
Ditto ignores Flameshot's private clipboard marker, so the image is cloned
back onto the clipboard without that marker after a successful capture.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ClipboardSequence {
    [DllImport("user32.dll")]
    public static extern uint GetClipboardSequenceNumber();
}
'@

$flameshot = 'C:\Program Files\Flameshot\bin\flameshot.exe'
if (!(Test-Path -LiteralPath $flameshot)) { exit 2 }

$before = [ClipboardSequence]::GetClipboardSequenceNumber()
$capture = Start-Process -FilePath $flameshot -ArgumentList 'gui --clipboard' -WindowStyle Hidden -PassThru
$capture.WaitForExit()

$image = $null
$deadline = (Get-Date).AddSeconds(10)
do {
    Start-Sleep -Milliseconds 100
    if ([ClipboardSequence]::GetClipboardSequenceNumber() -eq $before) { continue }
    try {
        $data = [System.Windows.Forms.Clipboard]::GetDataObject()
        if ($data.GetDataPresent([System.Windows.Forms.DataFormats]::Bitmap) -or
            $data.GetDataPresent([System.Windows.Forms.DataFormats]::Dib)) {
            $image = [System.Windows.Forms.Clipboard]::GetImage()
        }
    }
    catch {
        $image = $null
    }
} while ($null -eq $image -and (Get-Date) -lt $deadline)

if ($null -eq $image) { exit 3 }

try {
    $bitmap = New-Object System.Drawing.Bitmap $image
    [System.Windows.Forms.Clipboard]::SetDataObject($bitmap, $true)
    $bitmap.Dispose()
}
finally {
    $image.Dispose()
}
exit 0
