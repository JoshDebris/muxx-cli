@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0muxx-core.ps1" %*
exit /b %ERRORLEVEL%
