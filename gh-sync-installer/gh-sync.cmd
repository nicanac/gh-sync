@echo off
REM gh-sync -- Sync .github golden source to/from projects
REM Usage: gh-sync push|pull|diff|status|init [ProjectPath] [-DryRun] [-Force]

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0gh-sync.ps1" %*
