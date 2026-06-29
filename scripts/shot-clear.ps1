# shot-clear.ps1 — standalone entry point so `shot-clear` works even without the profile loaded.
# Usage: powershell -STA -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.claude\scripts\shot-clear.ps1" [-Force]
. "$PSScriptRoot\shot-tools.ps1"
shot-clear @args
