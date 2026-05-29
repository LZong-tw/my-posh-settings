# my-posh-settings

Personal PowerShell profile shared by Windows PowerShell 5.1 and PowerShell 7+.
It mirrors the shared behavior from
[`my-zsh-settings`](https://github.com/LZong-tw/my-zsh-settings) where the
PowerShell ecosystem has a clean equivalent.

## Install

```powershell
git clone https://github.com/LZong-tw/my-posh-settings.git C:\dev\my-posh-settings
winget install JanDeDobbeleer.OhMyPosh -e
oh-my-posh font install Meslo --headless
C:\dev\my-posh-settings\install.ps1
```

`install.ps1` writes a one-line stub to both `$PROFILE` paths that dot-sources
`Microsoft.PowerShell_profile.ps1` from this repo. Existing profiles are backed
up first. Edit the repo file and changes apply on next shell start — no
re-install needed.

Set Windows Terminal's profile font face to `MesloLGM Nerd Font Mono` so the
Powerlevel10k-style symbols render correctly. Existing tabs may need to be
reopened after installing the font.

If you cloned to a different path, pass it explicitly:

```powershell
.\install.ps1 -RepoRoot D:\code\my-posh-settings
```

## What's in it

| Component | What it does |
| --- | --- |
| Oh My Posh | Loads `themes/lzong-kali-p10k.omp.json`, a two-line Kali/Powerlevel10k-inspired prompt with OS, user/host, path, git, status, duration, Python, Node, and time. Runtime info is rendered as normal prompt segments instead of `rprompt`/`transient_prompt` to avoid Windows Terminal redraw flicker on Enter |
| PSReadLine | Emacs editing, duplicate-aware history, inline history suggestions, menu completion, `Ctrl+U`, `Ctrl+Left/Right`, `Ctrl+Delete`, `Ctrl+R`, `Tab`, and `Shift+Tab` |
| `dev <subdir>` | `cd C:\dev\<subdir>`, with `Tab` completion sourced from the zoxide DB (frecency-ranked) plus any unseen `C:\dev\*` directories |
| `z <part-of-path>` | [zoxide](https://github.com/ajeetdsouza/zoxide) smart cd, with `Tab` completion against the zoxide DB |
| `vi` → `vim` | alias if vim is installed |
| zsh-style aliases | Git (`g`, `gst`, `gp`, ...), Docker Compose (`dco`, `dup`, ...), Composer/Laravel (`ci`, `art`, ...), `ll`/`la`/`l`, `history`, `myip`, `ports`, `killport`, `mkcd`, `take`, `takegit`, `reload` |
| PowerToys CommandNotFound | suggests winget package if a command is missing |
| `kill-orphan-serena` | emergency cleanup for [Serena](https://github.com/oraios/serena) MCP process trees whose expected parent is gone |

## Prerequisites (optional, profile guards each)

- [Oh My Posh](https://ohmyposh.dev/): `winget install JanDeDobbeleer.OhMyPosh -e`
- Meslo Nerd Font for prompt glyphs: `oh-my-posh font install Meslo --headless`
- Windows Terminal profile font face: `MesloLGM Nerd Font Mono`
- [zoxide](https://github.com/ajeetdsouza/zoxide): `winget install ajeetdsouza.zoxide`
- [PowerToys](https://github.com/microsoft/PowerToys) (for CommandNotFound)
- [eza](https://github.com/eza-community/eza) (optional richer `ll`/`la`/`l`)
- [Vim](https://www.vim.org/)

## Execution policy note

Windows PowerShell 5.1 has `Restricted` execution policy by default and will
refuse to load this unsigned profile. Allow local scripts for your account:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

PowerShell 7+ defaults to `RemoteSigned` and works out of the box.
