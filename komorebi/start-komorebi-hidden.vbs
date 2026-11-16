Option Explicit

Dim shell
Set shell = CreateObject("WScript.Shell")
WScript.Sleep 3000
shell.CurrentDirectory = shell.ExpandEnvironmentStrings("%USERPROFILE%")
shell.Run "taskkill.exe /f /im komorebi.exe", 0, True
shell.Run "taskkill.exe /f /im komorebi-bar.exe", 0, True
shell.Run "taskkill.exe /f /im komorebic.exe", 0, True
shell.Run "taskkill.exe /f /im whkd.exe", 0, True
shell.Run Chr(34) & "C:\Program Files\komorebi\bin\komorebic.exe" & Chr(34) & " start", 0, False
WScript.Sleep 5000
shell.Run Chr(34) & "C:\Program Files\whkd\bin\whkd.exe" & Chr(34) & " -c " & Chr(34) & shell.ExpandEnvironmentStrings("%USERPROFILE%") & "\.config\whkdrc" & Chr(34), 0, False
shell.Run Chr(34) & "C:\Program Files\komorebi\bin\komorebi-bar.exe" & Chr(34) & " -c " & Chr(34) & shell.ExpandEnvironmentStrings("%USERPROFILE%") & "\komorebi.bar.json" & Chr(34), 0, False
