Set oShell = CreateObject("WScript.Shell")
Set oFSO   = CreateObject("Scripting.FileSystemObject")
sDir = oFSO.GetParentFolderName(WScript.ScriptFullName)
oShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & sDir & "\SpotifyLauncher.ps1""", 0, False
