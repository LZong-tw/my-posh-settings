# my-posh-settings — shared profile for Windows PowerShell 5.1 and PowerShell 7+
# Source of truth: https://github.com/LZong-tw/my-posh-settings

$MyPoshSettingsRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Test-Command {
    param([Parameter(Mandatory)][string]$Name)
    [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Remove-AliasIfExists {
    param([Parameter(Mandatory)][string[]]$Name)
    foreach ($aliasName in $Name) {
        if (Test-Path "Alias:$aliasName") {
            Remove-Item "Alias:$aliasName" -Force -ErrorAction SilentlyContinue
        }
    }
}

#region PowerToys CommandNotFound
#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module
if (Get-Module -ListAvailable -Name Microsoft.WinGet.CommandNotFound) {
    Import-Module -Name Microsoft.WinGet.CommandNotFound
}
#f45873b3-b655-43a6-b217-97c00aa0db58
#endregion

#region PSReadLine — zsh/Kali-style editing
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine

    $psReadLineOptions = @{
        EditMode            = 'Emacs'
        HistoryNoDuplicates = $true
        MaximumHistoryCount = 50000
        BellStyle           = 'None'
    }
    Set-PSReadLineOption @psReadLineOptions

    $setOption = Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue
    if ($setOption.Parameters.ContainsKey('PredictionSource')) {
        try {
            Set-PSReadLineOption -PredictionSource History
        } catch {
            # Redirected/non-VT sessions cannot enable predictions.
        }
    }
    if ($setOption.Parameters.ContainsKey('PredictionViewStyle')) {
        try {
            Set-PSReadLineOption -PredictionViewStyle InlineView
        } catch {
            # Keep profile loading quiet in non-interactive sessions.
        }
    }

    $keyBindings = @(
        @('Ctrl+u', 'BackwardDeleteLine'),
        @('Ctrl+LeftArrow', 'BackwardWord'),
        @('Ctrl+RightArrow', 'ForwardWord'),
        @('Ctrl+Delete', 'ForwardDeleteWord'),
        @('Delete', 'DeleteChar'),
        @('Home', 'BeginningOfLine'),
        @('End', 'EndOfLine'),
        @('Ctrl+r', 'ReverseSearchHistory'),
        @('Shift+Tab', 'MenuComplete'),
        @('Tab', 'MenuComplete'),
        @('Ctrl+z', 'Undo')
    )
    foreach ($binding in $keyBindings) {
        try {
            Set-PSReadLineKeyHandler -Chord $binding[0] -Function $binding[1]
        } catch {
            # Older PSReadLine builds may not expose every function/chord.
        }
    }
}
#endregion

#region Aliases and zsh-style helpers
Remove-AliasIfExists -Name history, gs, ci

if (Test-Command vim) {
    Set-Alias vi vim
}

function history {
    param([int]$Count = 0)
    if ($Count -le 0) {
        Get-History -Count ([int]::MaxValue)
        return
    }
    Get-History -Count $Count
}

function g { git @args }
function ga { git add @args }
function gaa { git add --all @args }
function gcam { git commit -a -m @args }
function gcmsg { git commit -m @args }
function gco { git checkout @args }
function gd { git diff @args }
function gl { git pull @args }
function gp { git push @args }
function gst { git status @args }
function gs { git status @args }
function glog { git log --oneline --graph -20 @args }

function d { docker @args }
function dco { docker compose @args }
function dcb { docker compose build @args }
function ddn { docker compose down @args }
function dex { docker exec -it @args }
function dlogs { docker compose logs -f @args }
function dps { docker compose ps @args }
function dup { docker compose up -d @args }
function dc { docker compose @args }
if (-not (Test-Command docker) -and (Test-Command podman)) {
    function docker { podman @args }
}

function c { composer @args }
function ci { composer install @args }
function cu { composer update @args }
function cda { composer dump-autoload -o @args }
function art { php artisan @args }
function pa { php artisan @args }
function mfs { php artisan migrate:fresh --seed @args }

if (Test-Command eza) {
    function l { eza --icons --git @args }
    function ll { eza -l --icons --git @args }
    function la { eza -la --icons --git @args }
} else {
    function l { Get-ChildItem @args }
    function ll { Get-ChildItem @args }
    function la { Get-ChildItem -Force @args }
}

function myip {
    (Invoke-RestMethod -UseBasicParsing -Uri 'http://ipecho.net/plain').Trim()
}

function ports {
    Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Sort-Object LocalPort |
        ForEach-Object {
            $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
            [pscustomobject]@{
                LocalAddress = $_.LocalAddress
                LocalPort    = $_.LocalPort
                PID          = $_.OwningProcess
                ProcessName  = $proc.ProcessName
            }
        } |
        Format-Table -AutoSize
}

function ports_full {
    netstat -ano -p tcp
}

function killport {
    param([Parameter(Mandatory)][int]$Port)
    $pids = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty OwningProcess -Unique
    if (-not $pids) {
        Write-Host "No process is listening on port $Port." -ForegroundColor Green
        return
    }
    foreach ($targetPid in $pids) {
        Stop-Process -Id $targetPid -Force
    }
}

function mkcd {
    param([Parameter(Mandatory)][string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location $Path
}

function takegit {
    param([Parameter(Mandatory)][string]$Url)
    git clone $Url
    if ($LASTEXITCODE -ne 0) { return }
    $name = [IO.Path]::GetFileNameWithoutExtension(($Url.TrimEnd('/').Split('/')[-1]))
    if ($name) { Set-Location $name }
}

function take {
    param([Parameter(Mandatory)][string]$PathOrUrl)
    if ($PathOrUrl -match '^(https?|git@)') {
        takegit $PathOrUrl
        return
    }
    mkcd $PathOrUrl
}

function reload {
    . $PROFILE
}
#endregion

#region Quick directory jumps
# `dev <subdir>` -> cd C:\dev\<subdir>
function dev {
    param([Parameter(Position = 0)][string]$Subdir)
    Set-Location "C:\dev\$Subdir"
}

Register-ArgumentCompleter -CommandName dev -ParameterName Subdir -ScriptBlock {
    param($cmd, $param, $word)
    $seen = @{}
    if (Test-Command zoxide) {
        zoxide query --list 2>$null |
            Where-Object { $_ -like 'C:\dev\*' } |
            ForEach-Object { Split-Path $_ -Leaf } |
            ForEach-Object { $seen[$_] = $true; $_ } |
            Where-Object { $_ -like "*$word*" } |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', "C:\dev\$_") }
    }
    Get-ChildItem 'C:\dev' -Directory -ErrorAction SilentlyContinue |
        Where-Object { -not $seen[$_.Name] -and $_.Name -like "*$word*" } |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_.Name, $_.Name, 'ParameterValue', $_.FullName) }
}
#endregion

#region zoxide (smart cd: `z <part-of-path>`)
if (Test-Command zoxide) {
    Invoke-Expression (& { (zoxide init powershell) -join "`n" })

    Remove-Item Alias:z -Force -ErrorAction SilentlyContinue
    function z {
        param(
            [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
            [string[]]$Query
        )
        __zoxide_z @Query
    }
    Register-ArgumentCompleter -CommandName z -ParameterName Query -ScriptBlock {
        param($cmd, $param, $word)
        (zoxide query --list 2>$null) |
            Where-Object { $_ -like "*$word*" } |
            ForEach-Object {
                $leaf = Split-Path $_ -Leaf
                [System.Management.Automation.CompletionResult]::new($leaf, $leaf, 'ParameterValue', $_)
            }
    }
}
#endregion

#region kill-orphan-serena
function kill-orphan-serena {
    [CmdletBinding()] param([switch]$Force)
    $byPid = @{}
    Get-CimInstance Win32_Process | ForEach-Object { $byPid[[int]$_.ProcessId] = $_ }

    $serena = $byPid.Values | Where-Object { $_.CommandLine -match 'serena' -and $_.Name -ne 'powershell.exe' -and $_.Name -ne 'pwsh.exe' }
    $roots = $serena | Where-Object {
        $p = $byPid[[int]$_.ParentProcessId]
        -not $p -or $p.CommandLine -notmatch 'serena'
    }
    $orphans = $roots | Where-Object {
        $p = $byPid[[int]$_.ParentProcessId]
        -not $p -or ($p.Name -ne 'claude.exe' -and $p.Name -ne 'node.exe')
    }

    if (-not $orphans) { Write-Host "No orphan Serena trees." -ForegroundColor Green; return }

    Write-Host "Orphan Serena tree(s):" -ForegroundColor Yellow
    $orphans | ForEach-Object {
        $cl = if ($_.CommandLine.Length -gt 100) { $_.CommandLine.Substring(0, 100) + '...' } else { $_.CommandLine }
        "  PID=$($_.ProcessId)  parent=$($_.ParentProcessId)(dead/unexpected)  $($_.Name)  $cl"
    }

    if (-not $Force) {
        $ans = Read-Host "`nKill these trees? [y/N]"
        if ($ans -notmatch '^[yY]') { Write-Host "Aborted."; return }
    }
    foreach ($o in $orphans) { taskkill /T /F /PID $o.ProcessId 2>&1 | Out-Null }
    Write-Host "Killed $($orphans.Count) tree(s)." -ForegroundColor Green
}
#endregion

#region Oh My Posh prompt
$themePath = Join-Path $MyPoshSettingsRoot 'themes\lzong-kali-p10k.omp.json'
if ((Test-Command oh-my-posh) -and (Test-Path $themePath)) {
    $ompShell = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell' } else { 'pwsh' }
    oh-my-posh init $ompShell --config $themePath | Invoke-Expression
}
#endregion
