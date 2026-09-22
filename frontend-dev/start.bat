@echo off
REM Double-click this file to launch the Nura frontends (Windows).
REM It just runs start.ps1 with the execution policy relaxed for this one process.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start.ps1"
