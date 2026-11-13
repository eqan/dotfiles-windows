Option Explicit

Dim shell, exe
Set shell = CreateObject("WScript.Shell")
If WScript.Arguments.Count < 1 Then WScript.Quit 2

Dim service, processes
Set service = GetObject("winmgmts:\\.\root\cimv2")
Set processes = service.ExecQuery("SELECT * FROM Win32_Process WHERE Name='vim_ahk.exe'")
If processes.Count > 0 Then WScript.Quit 0

exe = WScript.Arguments(0)
WScript.Sleep 3000
' Run in the logged-on interactive session with elevated task privileges.
shell.Run Chr(34) & exe & Chr(34), 1, False
