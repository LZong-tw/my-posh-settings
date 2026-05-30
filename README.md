# my-posh-settings

Personal PowerShell profile shared by Windows PowerShell 5.1 and PowerShell 7+.
It mirrors the shared behavior from
[`my-zsh-settings`](https://github.com/LZong-tw/my-zsh-settings) where the
PowerShell ecosystem has a clean equivalent.

## Install

```powershell
git clone https://github.com/LZong-tw/my-posh-settings.git C:\dev\my-posh-settings
C:\dev\my-posh-settings\install.ps1 -WithDeps
```

`install.ps1` writes a one-line stub to both `$PROFILE` paths that dot-sources
`Microsoft.PowerShell_profile.ps1` from this repo. Existing profiles are backed
up first. Edit the repo file and changes apply on next shell start — no
re-install needed.

`-WithDeps` is the PowerShell equivalent of `my-zsh-settings/install.sh
--with-deps`: it asks `winget` to install Oh My Posh, zoxide, eza, Vim, and
PowerToys. You can omit it if those tools are already installed or you prefer to
manage them yourself.

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
| Oh My Posh | Loads `themes/lzong-p10k.omp.json`, a visual port of `my-zsh-settings/zsh/.p10k.zsh`: two-line prompt, OS / directory / git on the left, status / duration / Python environment / `at hh:mm:ss AM/PM` on the right, Powerlevel10k-style separators, and p10k color indexes so the terminal palette controls the final look. Local `user@host` and direct Node version are intentionally omitted because the zsh source hides default context and comments out direct `node_version` |
| Kali prompt fallback | If Oh My Posh is unavailable, falls back to a Kali-style two-line prompt with `user㉿host`, virtualenv marker, blank-line-before-prompt behavior, and `Ctrl+P` toggle between two-line and one-line modes. This is only a fallback; Oh My Posh remains the normal prompt |
| Prompt performance | Keeps the prompt visually p10k-compatible while avoiding avoidable redraw work: git status is cached briefly per repository and guarded by a timeout; the Python environment segment reads `VIRTUAL_ENV` / `CONDA_DEFAULT_ENV` directly instead of probing `python.exe` on every prompt; startup avoids unnecessary PSReadLine, `vim`, Docker/Podman, zoxide, and `eza` command scans |
| Lazy-load parity with zsh | Ports the `my-zsh-settings` fast-path where PowerShell has a clean equivalent: Claude agent sessions, or shells launched with `MY_POSH_AGENT_FAST_PATH=1`, skip the interactive prompt stack; Docker/Podman and zoxide command discovery is cached after first resolution; `kubectl` PowerShell completion is registered as a first-Tab loader instead of running `kubectl completion powershell` during startup. NVM is not ported because nvm-windows is an executable, not a shell function that must be sourced |
| PSReadLine | Emacs editing, duplicate-aware history, inline history suggestions, menu completion, Kali-inspired syntax colors, grey inline predictions, `Ctrl+U`, `Ctrl+Left/Right`, `Ctrl+Delete`, `Ctrl+R`, `Tab`, `Shift+Tab`, `PageUp`, and `PageDown` |
| `dev <subdir>` | `cd C:\dev\<subdir>`, with `Tab` completion sourced from the zoxide DB (frecency-ranked) plus any unseen `C:\dev\*` directories. Directory fallback completion uses natural numeric sorting, mirroring zsh's `numericglobsort` where PowerShell has a useful equivalent |
| `z <part-of-path>` | [zoxide](https://github.com/ajeetdsouza/zoxide) smart cd, with `Tab` completion against the zoxide DB. It is initialized after Oh My Posh so its prompt hook keeps recording newly visited directories, including after `reload`; command discovery prefers the WinGet path before falling back to `PATH` |
| `vi` → `vim` | zsh-style alias; resolution is left to the shell when used so startup does not probe `PATH` |
| zsh-style aliases | Git (`g`, `gst`, `gp`, ...), Docker Compose (`dco`, `dup`, ...), Composer/Laravel (`ci`, `art`, ...), `ls`/`l`/`ll`/`la` via `eza` when available, `history`, `myip`, `ports`, `killport`, `mkcd`, `take`, `takegit`, `reload` |
| `eza` resolver | Uses the WinGet package path when present, otherwise falls back to `eza` from `PATH` |
| PowerToys CommandNotFound | optional, because importing it costs noticeable startup time. Set `MY_POSH_ENABLE_COMMAND_NOT_FOUND=1` in the user environment to enable winget suggestions for missing commands |
| `kill-orphan-serena` | emergency cleanup for [Serena](https://github.com/oraios/serena) MCP process trees whose expected parent is gone |

## Kali features synced from my-zsh-settings

The zsh repo now carries Kali's interactive defaults in the repo instead of
relying on Kali's `/etc/skel/.zshrc`. PowerShell ports the pieces that make sense
on Windows:

- Kali-like command-line coloring through PSReadLine's color table, including
  cyan commands, green parameters, yellow strings, red errors, and grey inline
  predictions.
- PageUp/PageDown history navigation and the existing Emacs-style editing
  bindings.
- A fallback Kali-style prompt when Oh My Posh is missing. When Oh My Posh is
  installed, the p10k-like prompt remains the source of truth. Set
  `MY_POSH_DISABLE_OMP=1` to test or force the fallback.
- `install.ps1 -WithDeps`, matching zsh's `install.sh --with-deps`, installs the
  Windows dependencies through `winget`.

zsh-only behavior such as `magicequalsubst`, `PROMPT_EOL_MARK`, plugin sourcing
from `/usr/share` or Homebrew, and nvm shell-function loading is intentionally
not copied because there is no direct PowerShell equivalent.

## Lazy-load notes

The zsh profile keeps startup fast by separating "environment needed by tools"
from "interactive UI": agents get a small prompt immediately; expensive
completion providers are loaded only on first use; prompt-time Kubernetes status
reads a cache instead of running `kubectl`.

PowerShell follows the same rule where it is safe:

- Agent sessions use a minimal prompt and return before Oh My Posh, PSReadLine,
  zoxide, and completion setup. Set `MY_POSH_DISABLE_AGENT_FAST_PATH=1` to force
  the full interactive stack.
- zoxide is still initialized eagerly, matching the zsh source, because its
  prompt hook is what records newly visited directories.
- `kubectl` completion is lazy. The first Tab press installs the native
  PowerShell completer; subsequent completions use the native completer.
- AWS and Google Cloud SDK completions are not imported at startup. Their CLIs
  remain normal external commands, and PowerShell does not need the zsh-style
  shell-function wrapper that `nvm` requires.

## Prerequisites (optional, profile guards each)

- [Oh My Posh](https://ohmyposh.dev/): `winget install JanDeDobbeleer.OhMyPosh -e`
- Meslo Nerd Font for prompt glyphs: `oh-my-posh font install Meslo --headless`
- Windows Terminal profile font face: `MesloLGM Nerd Font Mono`
- [zoxide](https://github.com/ajeetdsouza/zoxide): `winget install ajeetdsouza.zoxide`
- [PowerToys](https://github.com/microsoft/PowerToys) (for CommandNotFound)
- [eza](https://github.com/eza-community/eza): `winget install eza-community.eza -e` (optional richer `ls`/`l`/`ll`/`la`)
- [Vim](https://www.vim.org/)

## Execution policy note

Windows PowerShell 5.1 has `Restricted` execution policy by default and will
refuse to load this unsigned profile. Allow local scripts for your account:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

PowerShell 7+ defaults to `RemoteSigned` and works out of the box.
