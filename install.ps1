# install.ps1 — make Windows PowerShell 5.1 and PowerShell 7+ load the shared profile.
# Strategy: ensure profile files dot-source this repo's shared profile.
# Re-runnable: existing local profile content is preserved.

[CmdletBinding()]
param(
    [string]$RepoRoot = $PSScriptRoot,
    [switch]$WithDeps
)

function Install-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Name
    )

    $winget = Get-Command winget -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $winget) {
        Write-Host "[skip] winget not found; install $Name manually ($Id)." -ForegroundColor DarkYellow
        return
    }

    $installed = $false
    try {
        $listOutput = & $winget.Source list --id $Id -e --disable-interactivity 2>$null
        $installed = $LASTEXITCODE -eq 0 -and ($listOutput -match [regex]::Escape($Id))
    } catch {
        $installed = $false
    }
    if ($installed) {
        Write-Host "[ok] already installed: $Name ($Id)" -ForegroundColor Green
        return
    }

    Write-Host "[deps] $Name ($Id)" -ForegroundColor Cyan
    & $winget.Source install --id $Id -e --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[warn] winget could not install $Name; continuing." -ForegroundColor DarkYellow
    }
}

function Add-UserPathEntry {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @()
    if ($userPath) {
        $parts = $userPath -split ';' | Where-Object { $_ }
    }

    if ($parts -contains $Path) {
        Write-Host "[ok] PATH already contains: $Path" -ForegroundColor Green
        return
    }

    [Environment]::SetEnvironmentVariable('Path', (($parts + $Path) -join ';'), 'User')
    Write-Host "[set] User PATH += $Path" -ForegroundColor Cyan
}

if ($WithDeps) {
    Install-WingetPackage -Id 'JanDeDobbeleer.OhMyPosh' -Name 'Oh My Posh'
    Install-WingetPackage -Id 'ajeetdsouza.zoxide' -Name 'zoxide'
    Install-WingetPackage -Id 'eza-community.eza' -Name 'eza'
    Install-WingetPackage -Id 'vim.vim' -Name 'Vim'
    Install-WingetPackage -Id 'Microsoft.PowerToys' -Name 'PowerToys'
    Add-UserPathEntry -Path 'C:\Program Files\Vim\vim92'
}

$shared = Join-Path $RepoRoot 'Microsoft.PowerShell_profile.ps1'
if (-not (Test-Path $shared)) {
    throw "Shared profile not found: $shared"
}

$targets = @(
    "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",  # PS 5.1
    "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"          # PS 7+
)

$stubLine = ". `"$shared`""
$stub = "$stubLine`r`n"

foreach ($t in $targets) {
    $dir = Split-Path $t -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if (Test-Path $t) {
        $existing = Get-Content $t -Raw -ErrorAction SilentlyContinue
        $loadsShared = ($existing -split "`r?`n") | Where-Object { $_.Trim() -eq $stubLine } | Select-Object -First 1
        if ($loadsShared) {
            Write-Host "[ok] already loads shared profile: $t" -ForegroundColor Green
            continue
        }
        $bak = "$t.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $t $bak -Force
        Write-Host "[bak] $t -> $bak" -ForegroundColor DarkYellow
        [System.IO.File]::WriteAllText($t, ($stub + "`r`n" + $existing), (New-Object System.Text.UTF8Encoding $false))
        Write-Host "[set] prepended shared profile load: $t" -ForegroundColor Cyan
        continue
    }
    [System.IO.File]::WriteAllText($t, $stub, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "[set] $t" -ForegroundColor Cyan
}

Write-Host "`nDone. Open a new shell to pick up the profile." -ForegroundColor Green
Write-Host "Edit profile: $shared" -ForegroundColor DarkGray

if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    Write-Host "[hint] Oh My Posh is optional but recommended for the shared prompt:" -ForegroundColor DarkYellow
    Write-Host "       winget install JanDeDobbeleer.OhMyPosh -e" -ForegroundColor DarkGray
} else {
    $fontRegistryPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    $fontNames = @()
    try {
        $fontNames = (Get-ItemProperty $fontRegistryPath -ErrorAction Stop).PSObject.Properties.Name
    } catch {
        $fontNames = @()
    }

    if ($fontNames -notcontains 'MesloLGM Nerd Font Mono Regular (TrueType)') {
        Write-Host "[hint] Install the Meslo Nerd Font so prompt glyphs render correctly:" -ForegroundColor DarkYellow
        Write-Host "       oh-my-posh font install Meslo --headless" -ForegroundColor DarkGray
        Write-Host "       Then set Windows Terminal font face to: MesloLGM Nerd Font Mono" -ForegroundColor DarkGray
    }
}

$wingetEza = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\eza-community.eza_Microsoft.Winget.Source_8wekyb3d8bbwe\eza.exe'
if (-not (Get-Command eza -CommandType Application, ExternalScript -ErrorAction SilentlyContinue) -and -not (Test-Path $wingetEza)) {
    Write-Host "[hint] eza is optional but recommended for zsh-style ls/l/ll/la:" -ForegroundColor DarkYellow
    Write-Host "       winget install eza-community.eza -e" -ForegroundColor DarkGray
}
