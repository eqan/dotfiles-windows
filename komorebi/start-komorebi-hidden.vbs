Option Explicit

Dim shell, wmi, query, attempt
Set shell = CreateObject("WScript.Shell")
Set wmi = GetObject("winmgmts:\\.\root\cimv2")
WScript.Sleep 3000
shell.CurrentDirectory = shell.ExpandEnvironmentStrings("%USERPROFILE%")
shell.Run "taskkill.exe /f /im komorebi.exe", 0, True
shell.Run "taskkill.exe /f /im komorebi-bar.exe", 0, True
shell.Run "taskkill.exe /f /im komorebic.exe", 0, True
shell.Run "taskkill.exe /f /im whkd.exe", 0, True
shell.Run Chr(34) & "C:\Program Files\komorebi\bin\komorebic.exe" & Chr(34) & " start", 0, False
' Wait for the daemon instead of guessing how long startup will take.
For attempt = 1 To 30
    query = "SELECT * FROM Win32_Process WHERE Name='komorebi.exe'"
    If wmi.ExecQuery(query).Count > 0 Then Exit For
    WScript.Sleep 500
Next
shell.Run Chr(34) & "C:\Program Files\whkd\bin\whkd.exe" & Chr(34) & " -c " & Chr(34) & shell.ExpandEnvironmentStrings("%USERPROFILE%") & "\.config\whkdrc" & Chr(34), 0, False
' The IPC endpoint can appear shortly after the process. Retry the bar if
' komorebi-bar exits during that short initialization window.
For attempt = 1 To 6
    query = "SELECT * FROM Win32_Process WHERE Name='komorebi-bar.exe'"
    If wmi.ExecQuery(query).Count > 0 Then Exit For
    shell.Run Chr(34) & "C:\Program Files\komorebi\bin\komorebi-bar.exe" & Chr(34) & " -c " & Chr(34) & shell.ExpandEnvironmentStrings("%USERPROFILE%") & "\komorebi.bar.json" & Chr(34), 0, False
    WScript.Sleep 2500
Next
