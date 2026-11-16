param([Parameter(Mandatory = $true)][string]$Path)

$resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
if (Test-Path -LiteralPath $resolved -PathType Container) {
    $remote = "send $env:id cd `"$resolved`""
    & lf -remote $remote
    exit $LASTEXITCODE
}

$extension = [IO.Path]::GetExtension($resolved).ToLowerInvariant()
$editorExtensions = @(
    '.txt', '.md', '.markdown', '.mdx', '.rst', '.org', '.tex', '.latex',
    '.json', '.yaml', '.yml', '.toml', '.ini', '.conf', '.cfg', '.xml',
    '.html', '.css', '.js', '.ts', '.tsx', '.jsx', '.py', '.rs', '.go',
    '.c', '.h', '.cpp', '.hpp', '.cs', '.java', '.lua', '.vim', '.ps1',
    '.bat', '.cmd', '.sh', '.fish', '.sql', '.csv', '.gitignore', '.env'
)

if ($editorExtensions -contains $extension -or [IO.Path]::GetFileName($resolved) -match '^\.(gitignore|env|editorconfig)$') {
    $nvim = (Get-Command nvim.exe -ErrorAction SilentlyContinue).Source
    if (!$nvim) { $nvim = 'C:\Program Files\Neovim\bin\nvim.exe' }
    if (!(Test-Path -LiteralPath $nvim)) {
        throw "Neovim was not found for '$resolved'."
    }

    # Run Neovim in lf's terminal. lf suspends for the editor and resumes
    # cleanly after :q, which avoids the orphaned WezTerm/Komorebi domain
    # process and preserves a seamless terminal workflow.
    & $nvim -- $resolved
    exit $LASTEXITCODE
}

if ($extension -in @('.mp4', '.mkv', '.webm', '.avi', '.mov', '.wmv', '.mp3', '.flac', '.wav', '.ogg', '.m4a')) {
    if (Get-Command vlc.exe -ErrorAction SilentlyContinue) {
        Start-Process vlc.exe -ArgumentList @('--started-from-file', $resolved)
    } else {
        Start-Process -FilePath $resolved
    }
    exit 0
}

# Images, PDFs, archives and unknown files use their Windows file association.
Start-Process -FilePath $resolved
