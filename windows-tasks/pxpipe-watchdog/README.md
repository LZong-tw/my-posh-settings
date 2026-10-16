# pxpipe-watchdog

Keeps the local `pxpipe-proxy` (port 47821) alive on a Windows box that
sometimes runs out of memory or saturates its disk.

| File | Role |
|---|---|
| `task-win-pxpipe-proxy.vbs` | Logon launcher. Runs `npm i -g pxpipe-proxy@latest` (failure ignored), then the proxy, hidden. |
| `task-pxpipe-watchdog.vbs` | Runs every minute. Probes `/proxy-stats`; restarts the `WinPxpipeProxy` task when the proxy stops answering. |
| `tasks/*.xml` | Scheduled task definitions with `{{SID}}`, `{{USER}}`, `{{DIR}}`, `{{START}}` placeholders. |
| `install.ps1` | Copies the `.vbs` files to `~/.local/bin` and registers both tasks. |

## Install

```powershell
pwsh -File .\install.ps1
```

## Watchdog logic

- A healthy probe deletes the state file, so slow-but-answering never accumulates failures.
- The failure count belongs to one proxy pid; a freshly started proxy does not inherit the previous one's failures.
- Proxy process alive but silent: on the 3rd consecutive failure, re-probe with a 30 s timeout. If it answers (SLOW) leave it alone and re-probe next run; if not (DEAD) kill and restart.
- Task running with no proxy process (launcher busy on `npm i -g`, or wedged): restart on the 5th.
- No task running: start it.
- Log: `%LOCALAPPDATA%\pxpipe-watchdog.log`. Unhealthy runs log the probe status/error and probe vs wmi time; the pre-kill re-probe logs SLOW/DEAD with available RAM; kills log working set, CPU and threads; healthy probes over 2 s log `slow probe`; the first healthy probe after a restart logs `recovered: healthy Ns after restart`. State: `%LOCALAPPDATA%\pxpipe-watchdog.state` (`pid:count`), `pxpipe-watchdog.restart` (restart timestamp).

## Task settings that matter

`PxpipeWatchdog` uses `MultipleInstancesPolicy=IgnoreNew` and `ExecutionTimeLimit=PT3M`.
Under disk saturation one run takes 20-37 s; with the earlier `StopExisting` / 90 s
settings the next minute's run killed it (`LastTaskResult` 267014) before it could act.

## Pure VBScript

A PowerShell version never finished under paging (task result 0x800710E0, previous
instance still running), so this is wscript-only.

## Known gaps

- Not reproduced: a wedged watchdog being replaced. `IgnoreNew` means a hung run blocks detection for up to 3 minutes.
- The logon trigger of `WinPxpipeProxy` did not start the proxy on one clean boot (the watchdog did, 3 minutes later). Cause not investigated.
- The launcher wscript can wedge with no child process; the watchdog's "task running, no proxy" branch handles it after 5 failures.
