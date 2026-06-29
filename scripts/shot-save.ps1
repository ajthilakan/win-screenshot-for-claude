# shot-save.ps1 — standalone entry point so `shot-save` works even without the profile loaded.
# Usage: powershell -STA -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.claude\scripts\shot-save.ps1" all|<name...>
. "$PSScriptRoot\shot-tools.ps1"
shot-save @args
