Set objFSO = CreateObject("Scripting.FileSystemObject")
strDir = objFSO.GetParentFolderName(WScript.ScriptFullName)
strPS1 = strDir & "\StealthOverlay.ps1"

Set objShell = CreateObject("WScript.Shell")
strCommand = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File """ & strPS1 & """"

' 0 = Hide window completely, False = don't wait for return
objShell.Run strCommand, 0, False
