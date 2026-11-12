$ErrorActionPreference = 'Stop'

$repoRoot = $PSScriptRoot
$workspacerInstaller = Join-Path $repoRoot '.workspacer\install-workspacer.ps1'

if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'WinGet is unavailable. Install/update App Installer from Microsoft Store, then run this script again.'
}

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

# Windows-native equivalents of common Linux terminal tools.
$packages = @(
    'Microsoft.PowerShell',
    'Microsoft.Coreutils',
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

# NirCmd is kept in this repository when present; install it from the repo's
# nircmd folder without replacing a user-managed copy.
$nircmd = Join-Path $repoRoot 'nircmd'
if (Test-Path -LiteralPath $nircmd) {
    Write-Host "NirCmd files found in $nircmd"
}

[Environment]::SetEnvironmentVariable('WORKSPACER_CONFIG', $repoRoot, 'User')
$env:WORKSPACER_CONFIG = $repoRoot

if (Test-Path -LiteralPath $workspacerInstaller) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $workspacerInstaller
}
else {
    Write-Warning "Workspacer installer not found: $workspacerInstaller"
}

Write-Host 'Dotfiles bootstrap completed.'
