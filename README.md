# my-posh-settings

Personal PowerShell profile shared by Windows PowerShell 5.1 and PowerShell 7+.

## Install

```powershell
git clone https://github.com/LZong-tw/my-posh-settings.git C:\dev\my-posh-settings
C:\dev\my-posh-settings\install.ps1
```

`install.ps1` writes a one-line stub to both `$PROFILE` paths that dot-sources
`Microsoft.PowerShell_profile.ps1` from this repo. Existing profiles are backed
up first. Edit the repo file and changes apply on next shell start — no
re-install needed.

If you cloned to a different path, pass it explicitly:

```powershell
.\install.ps1 -RepoRoot D:\code\my-posh-settings
```

## What's in it

| Component | What it does |
| --- | --- |
| `dev <subdir>` | `cd C:\dev\<subdir>` |
| `z <part-of-path>` | [zoxide](https://github.com/ajeetdsouza/zoxide) smart cd |
| `vi` → `vim` | alias if vim is installed |
| PowerToys CommandNotFound | suggests winget package if a command is missing |
| `kill-orphan-serena` | kills [Serena](https://github.com/oraios/serena) MCP process trees whose `claude.exe` parent is gone — useful after Claude Code crashes |

## Prerequisites (optional, profile guards each)

- [zoxide](https://github.com/ajeetdsouza/zoxide): `winget install ajeetdsouza.zoxide`
- [PowerToys](https://github.com/microsoft/PowerToys) (for CommandNotFound)
- [Vim](https://www.vim.org/)

## Execution policy note

Windows PowerShell 5.1 has `Restricted` execution policy by default and will
refuse to load this unsigned profile. Allow local scripts for your account:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

PowerShell 7+ defaults to `RemoteSigned` and works out of the box.
