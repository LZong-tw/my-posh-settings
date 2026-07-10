# my-posh-settings — shared profile for Windows PowerShell 5.1 and PowerShell 7+
# Source of truth: https://github.com/LZong-tw/my-posh-settings

$MyPoshSettingsRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$MyPoshAgentFastPath =
    $env:MY_POSH_AGENT_FAST_PATH -eq '1' -or
    [bool]$env:CLAUDE_CODE_AGENT_ID
if ($MyPoshAgentFastPath -and $env:MY_POSH_DISABLE_AGENT_FAST_PATH -ne '1') {
    function global:prompt {
        "$($executionContext.SessionState.Path.CurrentLocation) $ "
    }
    return
}

function Test-Command {
    param([Parameter(Mandatory)][string]$Name)
    [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-RunnableApplication {
    param([Parameter(Mandatory)][string]$Path)

    Test-Path -LiteralPath $Path -PathType Leaf
}

function Resolve-ApplicationCommand {
    param(
        [string[]]$CandidatePaths = @(),
        [string[]]$Names = @()
    )

    foreach ($candidatePath in ($CandidatePaths | Where-Object { $_ } | Select-Object -Unique)) {
        if (Test-RunnableApplication $candidatePath) {
            return $candidatePath
        }
    }

    foreach ($name in ($Names | Where-Object { $_ } | Select-Object -Unique)) {
        $command = Get-Command $name -CommandType Application, ExternalScript -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($command) {
            if ($command.Path -and (Test-RunnableApplication $command.Path)) {
                return $command.Path
            }
            if ($command.Source) {
                return $command.Source
            }
        }
    }

    return $null
}

function Resolve-OhMyPoshCommand {
    $candidatePaths = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\bin\oh-my-posh.exe'),
        (Join-Path $env:ProgramFiles 'oh-my-posh\bin\oh-my-posh.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\oh-my-posh.exe')
    ) | Where-Object { $_ } | Select-Object -Unique

    foreach ($candidatePath in $candidatePaths) {
        if (Test-RunnableApplication $candidatePath) {
            return $candidatePath
        }
    }

    $command = Get-Command oh-my-posh -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($command.Path -and (Test-RunnableApplication $command.Path)) {
        return $command.Path
    }

    return $null
}

$script:MyPoshZoxideCommand = $null
$script:MyPoshZoxideResolved = $false
function Resolve-ZoxideCommand {
    if ($script:MyPoshZoxideResolved) {
        return $script:MyPoshZoxideCommand
    }

    $candidatePaths = @()
    if ($env:LOCALAPPDATA) {
        $candidatePaths += Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\ajeetdsouza.zoxide_Microsoft.Winget.Source_8wekyb3d8bbwe\zoxide.exe'
    }
    $script:MyPoshZoxideCommand = Resolve-ApplicationCommand -CandidatePaths $candidatePaths -Names @('zoxide.exe', 'zoxide')
    $script:MyPoshZoxideResolved = $true
    return $script:MyPoshZoxideCommand
}

function Remove-AliasIfExists {
    param([Parameter(Mandatory)][string[]]$Name)
    foreach ($aliasName in $Name) {
        if (Test-Path "Alias:$aliasName") {
            Remove-Item "Alias:$aliasName" -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-NaturalSortKey {
    param([AllowNull()][string]$Value)
    if ($null -eq $Value) {
        return ''
    }
    [regex]::Replace($Value, '\d+', {
            param($match)
            $match.Value.PadLeft(20, '0')
        })
}

#region PowerToys CommandNotFound
#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module
if ($env:MY_POSH_ENABLE_COMMAND_NOT_FOUND -eq '1' -and (Get-Module -ListAvailable -Name Microsoft.WinGet.CommandNotFound)) {
    Import-Module -Name Microsoft.WinGet.CommandNotFound
}
#f45873b3-b655-43a6-b217-97c00aa0db58
#endregion

#region PSReadLine — zsh/Kali-style editing
$psReadLineModule = Get-Module -Name PSReadLine
if (-not $psReadLineModule -and [Environment]::UserInteractive -and $Host.Name -eq 'ConsoleHost') {
    try {
        Import-Module PSReadLine -ErrorAction Stop
        $psReadLineModule = Get-Module -Name PSReadLine
    } catch {
        $psReadLineModule = $null
    }
}
if ($psReadLineModule) {

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
    if ($setOption.Parameters.ContainsKey('Colors')) {
        $kaliStyleColors = @{
            Command               = "`e[36m"
            Keyword               = "`e[36;1m"
            Parameter             = "`e[32m"
            Operator              = "`e[34;1m"
            String                = "`e[33m"
            Number                = "`e[33m"
            Variable              = "`e[35;1m"
            Type                  = "`e[36;1m"
            Comment               = "`e[30;1m"
            Error                 = "`e[31;1m"
            InlinePrediction      = "`e[38;2;153;153;153m"
            ListPrediction        = "`e[38;2;153;153;153m"
            ListPredictionTooltip = "`e[38;2;153;153;153m"
            Selection             = "`e[30;47m"
        }
        try {
            Set-PSReadLineOption -Colors $kaliStyleColors
        } catch {
            try {
                Set-PSReadLineOption -Colors @{
                    Command          = "`e[36m"
                    Parameter        = "`e[32m"
                    String           = "`e[33m"
                    InlinePrediction = "`e[38;2;153;153;153m"
                }
            } catch {
                # Older PSReadLine builds may not support every color token.
            }
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
        @('PageUp', 'BeginningOfHistory'),
        @('PageDown', 'EndOfHistory'),
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
Remove-AliasIfExists -Name history, gs, ci, ls

Set-Alias vi vim -ErrorAction SilentlyContinue

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

$MyPoshPodmanCommand = Join-Path $env:ProgramFiles 'RedHat\Podman\podman.exe'
$script:MyPoshDockerCommand = $null
$script:MyPoshDockerResolved = $false
function Resolve-DockerCommand {
    if ($script:MyPoshDockerResolved) {
        return $script:MyPoshDockerCommand
    }

    $script:MyPoshDockerCommand = Resolve-ApplicationCommand -Names @('docker.exe', 'docker')
    if (-not $script:MyPoshDockerCommand -and (Test-RunnableApplication $MyPoshPodmanCommand)) {
        $script:MyPoshDockerCommand = $MyPoshPodmanCommand
    }
    $script:MyPoshDockerResolved = $true
    return $script:MyPoshDockerCommand
}
function docker {
    $dockerCommand = Resolve-DockerCommand
    if ($dockerCommand) {
        & $dockerCommand @args
        return
    }
    Write-Error "Neither docker.exe nor podman.exe is available."
}
function d { docker @args }
function dco { docker compose @args }
function dcb { docker compose build @args }
function ddn { docker compose down @args }
function dex { docker exec -it @args }
function dlogs { docker compose logs -f @args }
function dps { docker compose ps @args }
function dup { docker compose up -d @args }
function dc { docker compose @args }

function c { composer @args }
function ci { composer install @args }
function cu { composer update @args }
function cda { composer dump-autoload -o @args }
function art { php artisan @args }
function pa { php artisan @args }
function mfs { php artisan migrate:fresh --seed @args }

function Resolve-EzaCommand {
    $wingetEza = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\eza-community.eza_Microsoft.Winget.Source_8wekyb3d8bbwe\eza.exe'
    if (Test-Path $wingetEza) {
        return $wingetEza
    }

    $command = Get-Command eza -CommandType Application, ExternalScript -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($command) {
        if ($command.Path) {
            return $command.Path
        }
        return $command.Source
    }

    return $null
}

$MyPoshEzaCommand = Resolve-EzaCommand
if ($MyPoshEzaCommand) {
    function eza { & $MyPoshEzaCommand @args }
    function ls { & $MyPoshEzaCommand --icons --git @args }
    function l { & $MyPoshEzaCommand --icons --git @args }
    function ll { & $MyPoshEzaCommand -l --icons --git @args }
    function la { & $MyPoshEzaCommand -la --icons --git @args }
} else {
    function ls { Get-ChildItem @args }
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
    $zoxideCommand = Resolve-ZoxideCommand
    if ($zoxideCommand) {
        & $zoxideCommand query --list 2>$null |
            Where-Object { $_ -like 'C:\dev\*' } |
            ForEach-Object { Split-Path $_ -Leaf } |
            ForEach-Object { $seen[$_] = $true; $_ } |
            Where-Object { $_ -like "*$word*" } |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', "C:\dev\$_") }
    }
    Get-ChildItem 'C:\dev' -Directory -ErrorAction SilentlyContinue |
        Where-Object { -not $seen[$_.Name] -and $_.Name -like "*$word*" } |
        Sort-Object { Get-NaturalSortKey $_.Name } |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_.Name, $_.Name, 'ParameterValue', $_.FullName) }
}
#endregion

#region Lazy external completions
$script:MyPoshKubectlCompletionLoaded = $false
function Enable-MyPoshKubectlCompletion {
    if ($script:MyPoshKubectlCompletionLoaded) {
        return
    }

    $kubectlCommand = Resolve-ApplicationCommand -Names @('kubectl.exe', 'kubectl')
    if (-not $kubectlCommand) {
        return
    }

    try {
        & $kubectlCommand completion powershell 2>$null | Out-String | Invoke-Expression
        $script:MyPoshKubectlCompletionLoaded = $true
    } catch {
        $script:MyPoshKubectlCompletionLoaded = $true
    }
}

Register-ArgumentCompleter -Native -CommandName kubectl -ScriptBlock {
    Enable-MyPoshKubectlCompletion
    @()
}
#endregion

#region Oh My Posh prompt
$myPoshPromptInitialized = $false
$themePath = Join-Path $MyPoshSettingsRoot 'themes\lzong-p10k.omp.json'
$ohMyPoshCommand = Resolve-OhMyPoshCommand
if ($env:MY_POSH_DISABLE_OMP -ne '1' -and $ohMyPoshCommand -and (Test-Path $themePath)) {
    $ompShell = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell' } else { 'pwsh' }
    try {
        & $ohMyPoshCommand init $ompShell --config $themePath | Invoke-Expression
        $myPoshPromptInitialized = $true
    } catch {
        $myPoshPromptInitialized = $false
    }
}

function Initialize-MyPoshFallbackPrompt {
    $global:MyPoshPromptAlternative = if ($env:MY_POSH_PROMPT_ALTERNATIVE) { $env:MY_POSH_PROMPT_ALTERNATIVE } else { 'twoline' }
    $script:MyPoshPromptRenderedOnce = $false
    $script:MyPoshFallbackPromptEnabled = $true

    function global:Toggle-MyPoshFallbackPrompt {
        if (-not $script:MyPoshFallbackPromptEnabled) {
            return
        }
        if ($global:MyPoshPromptAlternative -eq 'oneline') {
            $global:MyPoshPromptAlternative = 'twoline'
        } else {
            $global:MyPoshPromptAlternative = 'oneline'
        }
    }

    function global:prompt {
        $path = $executionContext.SessionState.Path.CurrentLocation
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        $symbol = if ($isAdmin) { '#' } else { '$' }
        $user = if ($env:USERNAME) { $env:USERNAME } else { 'user' }
        $hostName = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { [Environment]::MachineName }
        $venv = if ($env:VIRTUAL_ENV) { "($(Split-Path $env:VIRTUAL_ENV -Leaf))-" } else { '' }
        $topLeft = [char]0x250c
        $bottomLeft = [char]0x2514
        $horizontal = [char]0x2500
        $kaliSymbol = [char]0x327f

        if ($global:MyPoshPromptAlternative -eq 'oneline') {
            return "${venv}${user}@${hostName}:$path$symbol "
        }

        $prefix = if ($script:MyPoshPromptRenderedOnce) { "`n" } else { '' }
        $script:MyPoshPromptRenderedOnce = $true
        return "${prefix}${topLeft}${horizontal}${horizontal}${venv}(${user}${kaliSymbol}${hostName})-[$path]`n${bottomLeft}${horizontal}$symbol "
    }

    if ($psReadLineModule) {
        try {
            Set-PSReadLineKeyHandler -Chord 'Ctrl+p' -ScriptBlock {
                Toggle-MyPoshFallbackPrompt
                [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
            }
        } catch {
            # Prompt fallback still works without the toggle binding.
        }
    }

    return $true
}

if (-not $myPoshPromptInitialized -and $env:MY_POSH_DISABLE_FALLBACK_PROMPT -ne '1') {
    $myPoshPromptInitialized = Initialize-MyPoshFallbackPrompt
}
#endregion

#region zoxide (smart cd: `z <part-of-path>`)
$zoxideCommand = Resolve-ZoxideCommand
if ($zoxideCommand) {
    # zoxide records visited directories from a prompt hook. Load it after
    # oh-my-posh so it can use the final prompt function as its base.
    if ($myPoshPromptInitialized) {
        $global:__zoxide_hooked = 0
    }
    Invoke-Expression (& { (& $zoxideCommand init powershell) -join "`n" })

    if ($myPoshPromptInitialized -and (Get-Command __zoxide_hook -ErrorAction SilentlyContinue)) {
        function global:prompt {
            $null = __zoxide_hook
            if ($null -ne $global:__zoxide_prompt_old) {
                & $global:__zoxide_prompt_old
            }
        }
    }

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
        $zoxideCommand = Resolve-ZoxideCommand
        if (-not $zoxideCommand) {
            return
        }
        (& $zoxideCommand query --list 2>$null) |
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

#region Claude Code Router, Serena, and Headroom Custom Shortcuts
# Serena HTTP Singleton shortcuts.
function serena-status {
    node "$HOME\.serena\http-singleton\serena-http-singleton.mjs" status --project "C:\dev\sugar-dating" --port 9127
}

function serena-usage {
    param(
        [int]$Last = 40,
        [switch]$Top
    )

    if ($Top) {
        node "$HOME\.serena\http-singleton\serena-http-singleton.mjs" usage --project "C:\dev\sugar-dating" --port 9127 --top
        return
    }

    node "$HOME\.serena\http-singleton\serena-http-singleton.mjs" usage --project "C:\dev\sugar-dating" --port 9127 --last $Last
}

# headroom: `hc`=壓縮版 Claude Code(埠8787)/ `hcx`=壓縮版 Codex(埠8788)。原本的 claude/codex 不動,壞掉跑原指令當 fallback。
# PYTHONUTF8=1: headroom read_text() 沒指定編碼,繁中 Windows 預設 cp950 會把 UTF-8 的 CLAUDE.md/AGENTS.md 解碼炸掉
# --no-serena: 擋掉自動註冊 Serena(保護 pin 的設定) / --no-rtk: 不注入 headroom 自己的 rtk(已有自己的 RTK,也避開 cp950 crash 跟 10s timeout)
# 多開:同型(多個 hc 或多個 hcx)會自動重用同埠的既有 proxy(--no-proxy);claude 與 codex 分屬不同埠所以可並存。
#       想再開獨立一顆 proxy 就自己指埠:hc -p 8790 / hcx -p 8791
function hc {
    $env:PYTHONUTF8 = '1'
    # --- 穩定性鈕(2026-06-22):headroom 在 Claude Code 上實測省 0 token(全 cache 命中),
    #     但 proxy 偶爾被 memory/embedding 卡住 event loop 就會讓 client 報「API Connection Timeout」。
    #     以下不關 memory、只把容忍度調高,降低 timeout 機率。
    $env:API_TIMEOUT_MS = '600000'                   # Claude Code 端:proxy 慢一下不要直接判死(10 分鐘)
    $env:HEADROOM_CONNECT_TIMEOUT_SECONDS = '30'     # proxy connect+pool 容忍度(預設 10s;多 session 共用一顆 proxy 易撞滿)
    $env:HEADROOM_SKIP_UPSTREAM_CHECK = '1'          # 跳過 readyz 對上游的探測,少一個 stall 源
    $env:HEADROOM_DISABLE_KOMPRESS = '1'             # 已知 Kompress 會燒 CPU([[project_headroom_kompress_storm]])
    $port = 8787
    $a = @('wrap','claude','--memory','--no-serena','--no-rtk','-p',$port)
    if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) { $a += '--no-proxy' }
    headroom @a @args
}

# claude-sakana: Claude Code Router(CCR)+ Sakana Fugu API 的一鍵啟動。
# CCR 用獨立 CLAUDE_CONFIG_DIR(profiles/default-claude-code/claude)存放帳密,不會動到原生 claude 的 ~/.claude.json/.credentials.json;
# 但 projects/、plugins/ 是 junction、CLAUDE.md/RTK.md/gotchas.md 是 hardlink 指回 ~/.claude,對話紀錄、memory、hooks、permissions 共用。
# `ccr start` 本身是 idempotent(已在跑會直接回報 pid),每次都呼叫一次確保 gateway 活著,不用自己判斷 port。
function claude-sakana {
    ccr start --no-open | Out-Null
    ccr default-claude-code cli -- @args
}
#endregion
