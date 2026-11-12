Option Explicit

Dim shell, repoRoot, exe
Set shell = CreateObject("WScript.Shell")
repoRoot = shell.CurrentDirectory
If Right(repoRoot, 1) = "\." Then repoRoot = Left(repoRoot, Len(repoRoot) - 2)
If Right(repoRoot, 1) = "\" Then repoRoot = Left(repoRoot, Len(repoRoot) - 1)
repoRoot = shell.ExpandEnvironmentStrings("%USERPROFILE%") & "\.config\dotfiles-windows"
exe = "C:\Program Files\workspacer\workspacer.exe"
shell.Environment("Process")("WORKSPACER_CONFIG") = repoRoot
shell.CurrentDirectory = repoRoot
shell.Run Chr(34) & exe & Chr(34), 0, False
