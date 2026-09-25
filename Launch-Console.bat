@echo off
title Universal Stealth Assistant - Live Debug Console
cd /d "%~dp0"
echo ========================================================
echo  Universal Stealth Assistant - Live Debug Console
echo ========================================================
echo Running in Console / Debug Mode for testing...
echo Hotkeys:
echo   Ctrl+Shift+T : Auto-Solve MCQ (Screen OCR)
echo   Ctrl+Shift+S : Auto-Solve MCQ (Active Browser Tab or Screen)
echo   Ctrl+Shift+J : Force Java Solve
echo   Ctrl+Shift+C : Force C++ Solve
echo   Ctrl+Shift+Y : Force Python Solve
echo   Ctrl+Shift+B : Toggle Multi-Tab Browser
echo   Ctrl+Shift+P : Screenshot to Clipboard
echo   Ctrl+Shift+Q : Panic Kill / Exit
echo ========================================================
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0StealthOverlay.ps1" -Console
pause
