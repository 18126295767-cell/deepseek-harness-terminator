@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch-dsh.ps1" %*
exit /b %ERRORLEVEL%
