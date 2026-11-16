# Re-publish a Flameshot image without its "Clipboard Viewer Ignore" marker.
#
# Flameshot intentionally places a DeviceIndependentBitmap plus the standard
# Clipboard Viewer Ignore format on the clipboard.  That is fine for pasting,
# but clipboard managers may skip that update.  Ditto therefore misses the
# screenshot even though the image is visibly on the Windows clipboard.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$deadline = (Get-Date).AddSeconds(10)
$image = $null

do {
    $data = [System.Windows.Forms.Clipboard]::GetDataObject()
    $formats = @($data.GetFormats())
    # Flameshot normally publishes Clipboard Viewer Ignore, but after a
    # restart/version change it may publish only CF_BITMAP/CF_DIB. The bridge
    # is called immediately after `flameshot gui --clipboard` completes, so
    # accepting the image formats directly is more reliable than requiring a
    # private marker that Flameshot does not guarantee.
    if ($data.GetDataPresent([System.Windows.Forms.DataFormats]::Bitmap) -or
        $data.GetDataPresent([System.Windows.Forms.DataFormats]::Dib)) {
        $image = [System.Windows.Forms.Clipboard]::GetImage()
        break
    }
    Start-Sleep -Milliseconds 100
} while ((Get-Date) -lt $deadline)

if ($null -eq $image) { exit 3 }

try {
    # Clone the image before replacing the clipboard so it does not retain a
    # handle into the source clipboard object.
    $bitmap = New-Object System.Drawing.Bitmap $image
    [System.Windows.Forms.Clipboard]::SetDataObject($bitmap, $true)
    $bitmap.Dispose()
}
finally {
    $image.Dispose()
}
