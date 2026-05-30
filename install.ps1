# install.ps1 — make Windows PowerShell 5.1 and PowerShell 7+ load the shared profile.
# Strategy: write a tiny stub profile that dot-sources this repo's profile file.
# Re-runnable: existing profiles are backed up before overwrite.

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

    Write-Host "[deps] $Name ($Id)" -ForegroundColor Cyan
    & $winget.Source install --id $Id -e --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[warn] winget could not install $Name; continuing." -ForegroundColor DarkYellow
    }
}

if ($WithDeps) {
    Install-WingetPackage -Id 'JanDeDobbeleer.OhMyPosh' -Name 'Oh My Posh'
    Install-WingetPackage -Id 'ajeetdsouza.zoxide' -Name 'zoxide'
    Install-WingetPackage -Id 'eza-community.eza' -Name 'eza'
    Install-WingetPackage -Id 'vim.vim' -Name 'Vim'
    Install-WingetPackage -Id 'Microsoft.PowerToys' -Name 'PowerToys'
}

$shared = Join-Path $RepoRoot 'Microsoft.PowerShell_profile.ps1'
if (-not (Test-Path $shared)) {
    throw "Shared profile not found: $shared"
}

$targets = @(
    "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",  # PS 5.1
    "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"          # PS 7+
)

$stub = ". `"$shared`"`r`n"

foreach ($t in $targets) {
    $dir = Split-Path $t -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if (Test-Path $t) {
        $existing = Get-Content $t -Raw -ErrorAction SilentlyContinue
        if ($existing -eq $stub) {
            Write-Host "[ok] already linked: $t" -ForegroundColor Green
            continue
        }
        $bak = "$t.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $t $bak -Force
        Write-Host "[bak] $t -> $bak" -ForegroundColor DarkYellow
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
