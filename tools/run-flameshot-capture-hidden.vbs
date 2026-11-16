Option Explicit

Dim shell, scriptPath, command
Set shell = CreateObject("WScript.Shell")
scriptPath = "C:\Users\eqan\AppData\Local\Windows-Automation\tools\flameshot-capture.ps1"
command = "powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -STA -File """ & scriptPath & """"
shell.Run command, 0, True
