' Hidden logon launcher for the pxpipe proxy. Window style 0, wait so the
' scheduled task stays alive and RestartOnFailure still applies.
' Updates pxpipe-proxy to latest first (proxy is not running yet, so no file
' lock). Short fetch timeout so an offline logon does not stall the proxy;
' a failed update is ignored and the installed version starts.
Option Explicit
Dim shell, rc
Set shell = CreateObject("WScript.Shell")
shell.Run "cmd /c ""C:\nvm4w\nodejs\npm.cmd"" i -g pxpipe-proxy@latest --fetch-timeout=15000 --fetch-retries=0 --no-audit --no-fund > ""%TEMP%\pxpipe-update.log"" 2>&1", 0, True
rc = shell.Run("""C:\nvm4w\nodejs\node.exe"" ""C:\nvm4w\nodejs\node_modules\pxpipe-proxy\bin\cli.js""", 0, True)
WScript.Quit rc
