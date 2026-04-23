# my-posh-settings — shared profile for Windows PowerShell 5.1 and PowerShell 7+
# Source of truth: https://github.com/LZong-tw/my-posh-settings

#region PowerToys CommandNotFound
#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module
if (Get-Module -ListAvailable -Name Microsoft.WinGet.CommandNotFound) {
    Import-Module -Name Microsoft.WinGet.CommandNotFound
}
#f45873b3-b655-43a6-b217-97c00aa0db58
#endregion

#region Aliases
if (Get-Command vim -ErrorAction SilentlyContinue) {
    Set-Alias vi vim
}
#endregion

#region Quick directory jumps
# `dev <subdir>` -> cd C:\dev\<subdir>
function dev { Set-Location "C:\dev\$args" }
#endregion

#region zoxide (smart cd: `z <part-of-path>`)
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell) -join "`n" })

    # zoxide ships `z` as an alias for `__zoxide_z`, which uses $args (no param block),
    # so Register-ArgumentCompleter has nothing to bind to. Replace with a real function
    # that forwards to __zoxide_z but exposes a named parameter for completion.
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
# Find Serena MCP-server process trees whose root claude.exe parent is gone, then kill them.
# Usage: kill-orphan-serena         # interactive
#        kill-orphan-serena -Force  # no prompt
function kill-orphan-serena {
    [CmdletBinding()] param([switch]$Force)
    $byPid = @{}
    Get-CimInstance Win32_Process | ForEach-Object { $byPid[[int]$_.ProcessId] = $_ }

    $serena = $byPid.Values | Where-Object { $_.CommandLine -match 'serena' -and $_.Name -ne 'powershell.exe' }
    $roots  = $serena | Where-Object {
        $p = $byPid[[int]$_.ParentProcessId]
        -not $p -or $p.CommandLine -notmatch 'serena'
    }
    $orphans = $roots | Where-Object {
        $p = $byPid[[int]$_.ParentProcessId]
        -not $p -or $p.Name -ne 'claude.exe'
    }

    if (-not $orphans) { Write-Host "No orphan Serena trees." -ForegroundColor Green; return }

    Write-Host "Orphan Serena tree(s):" -ForegroundColor Yellow
    $orphans | ForEach-Object {
        $cl = if ($_.CommandLine.Length -gt 100) { $_.CommandLine.Substring(0,100) + '...' } else { $_.CommandLine }
        "  PID=$($_.ProcessId)  parent=$($_.ParentProcessId)(dead/not-claude)  $($_.Name)  $cl"
    }

    if (-not $Force) {
        $ans = Read-Host "`nKill these trees? [y/N]"
        if ($ans -notmatch '^[yY]') { Write-Host "Aborted."; return }
    }
    foreach ($o in $orphans) { taskkill /T /F /PID $o.ProcessId 2>&1 | Out-Null }
    Write-Host "Killed $($orphans.Count) tree(s)." -ForegroundColor Green
}
#endregion
