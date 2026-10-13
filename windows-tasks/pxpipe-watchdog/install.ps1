# Copies the two launcher scripts into $InstallDir and registers both scheduled
# tasks for the current user. Safe to re-run: existing tasks are replaced.
#
# -NamePrefix exists so the installer can be tested without touching the live
# tasks (e.g. -NamePrefix 'Test-' -InstallDir $env:TEMP\x). The .vbs files still
# refer to the real task name WinPxpipeProxy, so a prefixed install is for
# checking registration only, not for running the watchdog.
#
# Source is pure ASCII on purpose: PowerShell 5.1 reads BOM-less UTF-8 as ANSI.

param(
    [string]$InstallDir = (Join-Path $env:USERPROFILE '.local\bin'),
    [string]$NamePrefix = ''
)

$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Force $InstallDir | Out-Null
foreach ($f in 'task-pxpipe-watchdog.vbs', 'task-win-pxpipe-proxy.vbs') {
    Copy-Item (Join-Path $PSScriptRoot $f) (Join-Path $InstallDir $f) -Force
}

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$map = @{
    '{{SID}}'   = $id.User.Value
    '{{USER}}'  = $id.Name
    '{{DIR}}'   = $InstallDir
    '{{START}}' = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss') + (Get-Date).ToString('zzz')
}

foreach ($name in 'WinPxpipeProxy', 'PxpipeWatchdog') {
    $xml = Get-Content (Join-Path $PSScriptRoot "tasks\$name.xml") -Raw
    foreach ($k in $map.Keys) { $xml = $xml.Replace($k, $map[$k]) }
    Register-ScheduledTask -TaskName "$NamePrefix$name" -Xml $xml -Force | Out-Null
    Write-Host "OK  registered $NamePrefix$name"
}
