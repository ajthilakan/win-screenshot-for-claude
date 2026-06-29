# shot-watch.ps1 — standalone entry point so `shot-watch` works even without the profile loaded.
# Usage: powershell -STA -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.claude\scripts\shot-watch.ps1" [on|start] [-MaxSeconds N]
. "$PSScriptRoot\shot-tools.ps1"
shot-watch @args
