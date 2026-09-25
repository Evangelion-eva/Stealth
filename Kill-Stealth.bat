@echo off
echo Terminating any active Stealth Overlay instances...
powershell -NoProfile -Command "$myPid = $PID; Get-Process powershell, pwsh -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $myPid } | Where-Object { try { (Get-CimInstance Win32_Process -Filter ('ProcessId = ' + $_.Id)).CommandLine -match 'StealthOverlay.ps1' } catch { $false } } | Stop-Process -Force -ErrorAction SilentlyContinue"
echo Done.
timeout /t 1 >nul
exit
