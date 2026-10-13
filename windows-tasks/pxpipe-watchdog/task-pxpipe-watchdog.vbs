' Restarts the WinPxpipeProxy task when the proxy stops answering.
' Pure VBScript on purpose: under heavy paging pwsh took longer to start than the
' one-minute schedule, so every run was refused (0x800710E0) and nothing restarted.
' Run every minute by the PxpipeWatchdog scheduled task.
Option Explicit
Const TASK_NAME = "WinPxpipeProxy"
Const URL = "http://127.0.0.1:47821/proxy-stats"
Const PROXY_MATCH = "pxpipe-proxy\bin\cli.js"""   ' background proxy, not `cli.js warp -- ...`

Dim fso, stateFile, logFile, fails, tStart
tStart = Timer
Set fso = CreateObject("Scripting.FileSystemObject")
stateFile = CreateObject("WScript.Shell").ExpandEnvironmentStrings("%LOCALAPPDATA%\pxpipe-watchdog.state")
logFile = CreateObject("WScript.Shell").ExpandEnvironmentStrings("%LOCALAPPDATA%\pxpipe-watchdog.log")

Sub WriteLog(msg)
    Dim f: Set f = fso.OpenTextFile(logFile, 8, True)
    f.WriteLine Now & " " & msg
    f.Close
End Sub

Function Healthy()
    Dim http
    Healthy = False
    On Error Resume Next
    Set http = CreateObject("MSXML2.ServerXMLHTTP.6.0")
    http.setTimeouts 3000, 3000, 5000, 10000
    http.Open "GET", URL, False
    http.Send
    If Err.Number = 0 Then Healthy = (http.Status = 200)
    On Error GoTo 0
End Function

If Healthy() Then
    If fso.FileExists(stateFile) Then fso.DeleteFile stateFile
    WScript.Quit 0
End If

Dim task, wmi, procs, p, proxyAlive, running, proxyPid, parts
Set task = CreateObject("Schedule.Service")
task.Connect
Set task = task.GetFolder("\").GetTask(TASK_NAME)
running = (task.State = 4)

Set wmi = GetObject("winmgmts:\\.\root\cimv2")
Set procs = wmi.ExecQuery("SELECT ProcessId, CommandLine FROM Win32_Process WHERE Name = 'node.exe'")
proxyAlive = False
proxyPid = 0
For Each p In procs
    If Not IsNull(p.CommandLine) Then
        If Right(RTrim(p.CommandLine), Len(PROXY_MATCH)) = PROXY_MATCH Then
            proxyAlive = True
            proxyPid = p.ProcessId
        End If
    End If
Next

' The failure count belongs to one proxy pid. A freshly started proxy (node boot plus
' the launcher's npm update can take minutes under paging) must not inherit the
' failures of the process before it.
fails = 1
If fso.FileExists(stateFile) Then
    On Error Resume Next
    parts = Split(fso.OpenTextFile(stateFile).ReadLine, ":")
    If UBound(parts) = 1 Then
        If CLng(parts(0)) = proxyPid Then fails = CInt(parts(1)) + 1
    End If
    On Error GoTo 0
End If
fso.CreateTextFile(stateFile, True).WriteLine proxyPid & ":" & fails
WriteLog "unhealthy: proxy pid=" & proxyPid & " fails=" & fails & " task running=" & running & " (probe+wmi " & Round(Timer - tStart, 1) & "s)"

' Proxy process up but silent: three minutes of silence from that same process.
' Task running without a proxy process: the launcher is still running npm update,
' or it is wedged; allow five minutes before treating it as wedged.
If running And proxyAlive And fails < 3 Then WScript.Quit 0
If running And Not proxyAlive And fails < 5 Then WScript.Quit 0

For Each p In procs
    If Not IsNull(p.CommandLine) Then
        If Right(RTrim(p.CommandLine), Len(PROXY_MATCH)) = PROXY_MATCH Then
            WriteLog "killing unresponsive proxy pid " & p.ProcessId & " after " & fails & " failed probes"
            p.Terminate
        End If
    End If
Next
If task.State = 4 Then task.Stop 0
WScript.Sleep 2000
task.Run Null
fso.DeleteFile stateFile
WriteLog "restarted " & TASK_NAME & " (task was running=" & running & ", proxy process=" & proxyAlive & ")"
