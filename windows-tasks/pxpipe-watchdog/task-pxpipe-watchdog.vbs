' Restarts the WinPxpipeProxy task when the proxy stops answering.
' Pure VBScript on purpose: under heavy paging pwsh took longer to start than the
' one-minute schedule, so every run was refused (0x800710E0) and nothing restarted.
' Run every minute by the PxpipeWatchdog scheduled task.
Option Explicit
Const TASK_NAME = "WinPxpipeProxy"
Const URL = "http://127.0.0.1:47821/proxy-stats"
Const PROXY_MATCH = "pxpipe-proxy\bin\cli.js"""   ' background proxy, not `cli.js warp -- ...`
Const SLOW_PROBE_SECS = 2

Dim fso, stateFile, restartFile, logFile, fails, tStart, probeErr, probeStatus, probeSecs
tStart = Timer
Set fso = CreateObject("Scripting.FileSystemObject")
stateFile = CreateObject("WScript.Shell").ExpandEnvironmentStrings("%LOCALAPPDATA%\pxpipe-watchdog.state")
restartFile = CreateObject("WScript.Shell").ExpandEnvironmentStrings("%LOCALAPPDATA%\pxpipe-watchdog.restart")
logFile = CreateObject("WScript.Shell").ExpandEnvironmentStrings("%LOCALAPPDATA%\pxpipe-watchdog.log")

Sub WriteLog(msg)
    Dim f: Set f = fso.OpenTextFile(logFile, 8, True)
    f.WriteLine Now & " " & msg
    f.Close
End Sub

' receiveMs is the only timeout that differs between the normal probe and the
' pre-kill re-probe. Sets probeErr / probeStatus / probeSecs for the log.
Function Probe(receiveMs)
    Dim http, t0
    Probe = False
    probeErr = ""
    probeStatus = 0
    t0 = Timer
    On Error Resume Next
    Set http = CreateObject("MSXML2.ServerXMLHTTP.6.0")
    http.setTimeouts 3000, 3000, 5000, receiveMs
    http.Open "GET", URL, False
    http.Send
    If Err.Number <> 0 Then
        probeErr = "0x" & Hex(Err.Number) & " " & Replace(Err.Description, vbCrLf, " ")
    Else
        probeStatus = http.Status
        Probe = (probeStatus = 200)
    End If
    On Error GoTo 0
    probeSecs = Round(Timer - t0, 1)
End Function

Sub LogRecovery()
    If Not fso.FileExists(restartFile) Then Exit Sub
    On Error Resume Next
    WriteLog "recovered: healthy " & DateDiff("s", CDate(fso.OpenTextFile(restartFile).ReadLine), Now) & "s after restart"
    On Error GoTo 0
    fso.DeleteFile restartFile
End Sub

If Probe(10000) Then
    If probeSecs > SLOW_PROBE_SECS Then WriteLog "slow probe: " & probeSecs & "s (status " & probeStatus & ")"
    LogRecovery
    If fso.FileExists(stateFile) Then fso.DeleteFile stateFile
    WScript.Quit 0
End If

Dim probeFailSecs, probeFailInfo, tWmi
probeFailSecs = probeSecs
probeFailInfo = "status=" & probeStatus & " err=[" & probeErr & "]"

Dim task, wmi, procs, p, proxyAlive, running, proxyPid, parts
tWmi = Timer
Set task = CreateObject("Schedule.Service")
task.Connect
Set task = task.GetFolder("\").GetTask(TASK_NAME)
running = (task.State = 4)

Set wmi = GetObject("winmgmts:\\.\root\cimv2")
Set procs = wmi.ExecQuery("SELECT ProcessId, CommandLine, WorkingSetSize, KernelModeTime, UserModeTime, ThreadCount FROM Win32_Process WHERE Name = 'node.exe'")
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
WriteLog "unhealthy: proxy pid=" & proxyPid & " fails=" & fails & " task running=" & running & " (probe " & probeFailSecs & "s " & probeFailInfo & ", wmi+task " & Round(Timer - tWmi, 1) & "s, total " & Round(Timer - tStart, 1) & "s)"

' Proxy process up but silent: three minutes of silence from that same process.
' Task running without a proxy process: the launcher is still running npm update,
' or it is wedged; allow five minutes before treating it as wedged.
If running And proxyAlive And fails < 3 Then WScript.Quit 0
If running And Not proxyAlive And fails < 5 Then WScript.Quit 0

' Evidence for tuning the thresholds: is the proxy dead, or just slow? A 30 s
' re-probe plus the process and machine state at the moment of the kill.
Dim verdict, mem
If Probe(30000) Then
    verdict = "SLOW (answered 200 in " & probeSecs & "s)"
Else
    verdict = "DEAD (status=" & probeStatus & " err=[" & probeErr & "] after " & probeSecs & "s)"
End If
mem = "?"
On Error Resume Next
For Each p In wmi.ExecQuery("SELECT AvailableMBytes FROM Win32_PerfFormattedData_PerfOS_Memory")
    mem = p.AvailableMBytes
Next
On Error GoTo 0
WriteLog "pre-kill reprobe(30s): " & verdict & "; avail RAM " & mem & " MB"

For Each p In procs
    If Not IsNull(p.CommandLine) Then
        If Right(RTrim(p.CommandLine), Len(PROXY_MATCH)) = PROXY_MATCH Then
            WriteLog "killing unresponsive proxy pid " & p.ProcessId & " after " & fails & " failed probes (workingset " & Round(p.WorkingSetSize / 1048576, 1) & " MB, cpu " & Round((CDbl(p.KernelModeTime) + CDbl(p.UserModeTime)) / 10000000, 1) & "s, threads " & p.ThreadCount & ")"
            p.Terminate
        End If
    End If
Next
If task.State = 4 Then task.Stop 0
WScript.Sleep 2000
task.Run Null
fso.DeleteFile stateFile
fso.CreateTextFile(restartFile, True).WriteLine Now
WriteLog "restarted " & TASK_NAME & " (task was running=" & running & ", proxy process=" & proxyAlive & ")"
