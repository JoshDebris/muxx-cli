@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0muxx.ps1" %*
exit /b %ERRORLEVEL%
