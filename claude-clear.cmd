@rem Fast "clear" hook: starts PowerShell only when a "needs you" card is open.
@if exist "%~dp0progress\claude-*.json" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0claude-hook.ps1" clear
