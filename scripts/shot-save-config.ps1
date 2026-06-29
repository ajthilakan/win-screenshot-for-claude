# shot-save-config.ps1 — standalone entry point so `shot-save-config` works even without the profile loaded.
# Usage: powershell -STA -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.claude\scripts\shot-save-config.ps1" ['<path>'] [-Create]
. "$PSScriptRoot\shot-tools.ps1"
shot-save-config @args
