param(
    [Parameter(Mandatory = $true)][string]$Path,
    [int]$Width,
    [int]$Height,
    [int]$X,
    [int]$Y,
    [string]$Mode
)

if (Test-Path -LiteralPath $Path -PathType Container) {
    Get-ChildItem -LiteralPath $Path -Force | Select-Object Mode,Length,LastWriteTime,Name | Format-Table -AutoSize | Out-String -Width 180
    exit 0
}

$item = Get-Item -LiteralPath $Path -ErrorAction Stop
$extension = $item.Extension.ToLowerInvariant()
$textExtensions = @('.txt', '.md', '.markdown', '.tex', '.latex', '.json', '.yaml', '.yml', '.toml', '.ini', '.conf', '.xml', '.html', '.css', '.js', '.ts', '.py', '.rs', '.go', '.c', '.h', '.cpp', '.hpp', '.cs', '.java', '.lua', '.vim', '.ps1', '.bat', '.cmd', '.sh', '.sql', '.csv')

if ($textExtensions -contains $extension) {
    Get-Content -LiteralPath $Path -TotalCount 80 -ErrorAction SilentlyContinue
    exit 0
}

if ($extension -eq '.pdf' -and (Get-Command mutool.exe -ErrorAction SilentlyContinue)) {
    & mutool.exe draw -F txt -o - -- $Path 2>$null | Select-Object -First 80
    exit 0
}

if ($extension -in @('.zip', '.7z', '.rar', '.tar', '.gz')) {
    if (Get-Command 7z.exe -ErrorAction SilentlyContinue) { & 7z.exe l -ba -- $Path 2>$null | Select-Object -First 40; exit 0 }
}

"$($item.Name)  [$($item.Length) bytes]"
