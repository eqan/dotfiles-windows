Option Explicit

Dim shell, repoRoot, exe
Set shell = CreateObject("WScript.Shell")
Dim service, processes
Set service = GetObject("winmgmts:\\.\root\cimv2")
Set processes = service.ExecQuery("SELECT * FROM Win32_Process WHERE Name='workspacer.exe'")
If processes.Count > 0 Then WScript.Quit 0
repoRoot = shell.CurrentDirectory
If Right(repoRoot, 1) = "\." Then repoRoot = Left(repoRoot, Len(repoRoot) - 2)
If Right(repoRoot, 1) = "\" Then repoRoot = Left(repoRoot, Len(repoRoot) - 1)
repoRoot = shell.ExpandEnvironmentStrings("%USERPROFILE%") & "\.config\dotfiles-windows"
exe = "C:\Program Files\workspacer\workspacer.exe"
shell.Environment("Process")("WORKSPACER_CONFIG") = repoRoot
shell.CurrentDirectory = repoRoot
WScript.Sleep 3000
' Launch in the logged-on interactive session. Workspacer has no console window,
' so this keeps the app visible to the desktop without a hidden wrapper window.
shell.Run Chr(34) & exe & Chr(34), 1, False
