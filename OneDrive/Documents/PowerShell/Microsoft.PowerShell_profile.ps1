# Minimal Unix-oriented profile.
# No prompt framework, Git module, icon module, PATH scanning, or eager shell
# integrations are loaded here. This keeps new shells close to native speed.

if ($host.Name -eq 'ConsoleHost') {
    Import-Module PSReadLine -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineOption -EditMode Vi
    try {
        Set-PSReadLineOption -PredictionSource History
    }
    catch {
        # Older Windows PowerShell does not support prediction settings.
    }
    try {
        Set-PSReadLineOption -PredictionViewStyle InlineView
    }
    catch {
        # Keep the host default prediction view when InlineView is unavailable.
    }
    try {
        Set-PSReadLineKeyHandler -Key Tab -ScriptBlock {
            param($key, $arg)
            $before = $null
            $beforeCursor = 0
            [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$before, [ref]$beforeCursor)
            [Microsoft.PowerShell.PSConsoleReadLine]::AcceptSuggestion()
            $after = $null
            $afterCursor = 0
            [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$after, [ref]$afterCursor)
            if ($before -eq $after -and $beforeCursor -eq $afterCursor) {
                [Microsoft.PowerShell.PSConsoleReadLine]::MenuComplete()
            }
        }
    }
    catch {
        # Older PSReadLine uses the normal completion menu instead.
        Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    }
}

function global:prompt {
    $esc = [char]27
    $userIcon = [char]0xF007
    $folder = [char]0xF07B
    $arrow = [char]0x276F
    $reset = "${esc}[0m"
    $cyan = "${esc}[38;5;117m"
    $yellow = "${esc}[38;5;221m"
    $muted = "${esc}[38;5;244m"
    $location = $executionContext.SessionState.Path.CurrentLocation.ToString()
    if ($location.StartsWith($HOME, [System.StringComparison]::OrdinalIgnoreCase)) { $location = '~' + $location.Substring($HOME.Length) }
    "${cyan}${userIcon} $env:USERNAME ${muted}| ${yellow}$folder $location ${cyan}$arrow${reset} "
}

# Native Rust directory tools are resolved only when used, not during startup.
Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
function global:ls { if (Get-Command eza.exe -ErrorAction SilentlyContinue) { & eza.exe --icons --group-directories-first @args } else { Get-ChildItem @args } }
function global:ll { if (Get-Command eza.exe -ErrorAction SilentlyContinue) { & eza.exe --long --header --icons --group-directories-first @args } else { Get-ChildItem @args | Format-Table } }
function global:la { if (Get-Command eza.exe -ErrorAction SilentlyContinue) { & eza.exe --long --all --header --icons --group-directories-first @args } else { Get-ChildItem -Force @args | Format-Table } }
function global:tree { if (Get-Command eza.exe -ErrorAction SilentlyContinue) { & eza.exe --tree --icons @args } else { Get-ChildItem @args -Recurse } }
function global:y { & yazi.exe @args }

Remove-Item Alias:cat -Force -ErrorAction SilentlyContinue
function global:cat { if (Get-Command cat.exe -ErrorAction SilentlyContinue) { & cat.exe @args } else { Get-Content @args } }

function global:touch {
    param([Parameter(Mandatory, Position = 0)][string]$Path)
    if (Test-Path -LiteralPath $Path) { (Get-Item -LiteralPath $Path).LastWriteTime = Get-Date }
    else { New-Item -ItemType File -Path $Path -Force | Out-Null }
}

if (Test-Path -LiteralPath 'C:\Program Files\Neovim\bin\nvim.exe') { Set-Alias nvim 'C:\Program Files\Neovim\bin\nvim.exe' -Scope Global }
if (Test-Path -LiteralPath 'C:\Users\eqan\go\bin\lf.exe') { Set-Alias lf 'C:\Users\eqan\go\bin\lf.exe' -Scope Global }
if (Get-Command go.exe -ErrorAction SilentlyContinue) { Set-Alias go (Get-Command go.exe).Source -Scope Global }

function global:rprofile { . $PROFILE }
Set-Alias desktop Desktop.ps1 -Scope Global

function global:go-vim-ahk {
    $path = Join-Path $env:LOCALAPPDATA 'Windows-Automation'
    if (!(Test-Path -LiteralPath $path)) { throw "Vim AHK checkout was not found at $path." }
    Set-Location -LiteralPath $path
}
function global:go-dotfiles {
    $path = Join-Path $HOME '.config\dotfiles-windows'
    if (!(Test-Path -LiteralPath $path)) { throw "Dotfiles checkout was not found at $path." }
    Set-Location -LiteralPath $path
}
Set-Alias -Name vim-ahk -Value go-vim-ahk -Scope Global
Set-Alias -Name dotfiles -Value go-dotfiles -Scope Global

function global:refresh-vim-ahk {
    [CmdletBinding()]
    param([switch]$NoPull)
    $automationRoot = Join-Path $env:LOCALAPPDATA 'Windows-Automation'
    $taskName = 'AutoHotkey Vim (Windows-Automation)'
    $buildScript = Join-Path $automationRoot 'build.bat'
    if (!(Test-Path -LiteralPath $buildScript)) { throw "Windows-Automation was not found at $automationRoot. Run the dotfiles installer first." }
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Get-Process -Name vim_ahk -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    if (!$NoPull -and (Get-Command git.exe -ErrorAction SilentlyContinue)) {
        git.exe -C $automationRoot pull --ff-only
        if ($LASTEXITCODE -ne 0) { throw 'Windows-Automation could not be updated with git pull.' }
    }
    Push-Location $automationRoot
    try { & cmd.exe /d /c '.\build.bat'; if ($LASTEXITCODE -ne 0) { throw "Windows-Automation build failed with exit code $LASTEXITCODE." } }
    finally { Pop-Location }
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Start-ScheduledTask -TaskName $taskName
        Write-Host 'Vim AHK rebuilt and restarted through the elevated scheduled task.' -ForegroundColor Green
    }
    else {
        $vimExe = Join-Path $automationRoot 'vim_ahk\vim_ahk.exe'
        Start-Process -FilePath $vimExe -WorkingDirectory (Split-Path -Parent $vimExe)
        Write-Warning 'The elevated Vim AHK scheduled task was not found; started the executable normally.'
    }
}
Set-Alias vim-refresh refresh-vim-ahk -Scope Global

function global:which([string]$Command) { if (!$Command) { throw 'Usage: which command' }; (Get-Command $Command -ErrorAction Stop).Source }
function global:cd... { Set-Location ..\.. }
function global:cd.... { Set-Location ..\..\.. }
function global:md5 { Get-FileHash -Algorithm MD5 @args }
function global:sha1 { Get-FileHash -Algorithm SHA1 @args }
function global:sha256 { Get-FileHash -Algorithm SHA256 @args }

Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    winget complete --word="$($wordToComplete.Replace('"', '""'))" --commandline "$($commandAst.ToString().Replace('"', '""'))" --position $cursorPosition | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}







