# shot.ps1 — standalone entry point so `shot` works even without the profile loaded.
# Usage: powershell -STA -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.claude\scripts\shot.ps1" [-Quiet]
. "$PSScriptRoot\shot-tools.ps1"
Save-ClipboardShot @args
