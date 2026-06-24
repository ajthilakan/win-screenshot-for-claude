# install.ps1 — set up shot-for-claude on this machine.
# Copies the scripts to ~\.claude\scripts, creates the shots folder, and adds a
# single dot-source line to your PowerShell profile. Idempotent and safe to re-run.

$ErrorActionPreference = 'Stop'

$srcScripts  = Join-Path $PSScriptRoot 'scripts'
$destScripts = Join-Path $env:USERPROFILE '.claude\scripts'
$shotsDir    = Join-Path $env:USERPROFILE '.claude\shots'

New-Item -ItemType Directory -Path $destScripts -Force | Out-Null
New-Item -ItemType Directory -Path $shotsDir    -Force | Out-Null

Copy-Item (Join-Path $srcScripts '*.ps1') $destScripts -Force
Write-Host "Copied scripts to $destScripts" -ForegroundColor Green

# Add the loader line to the profile, only if it isn't already there.
$line = '. "$env:USERPROFILE\.claude\scripts\shot-tools.ps1"  # shot-for-claude'
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}
$existing = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if ($existing -notmatch 'shot-for-claude') {
    Add-Content -Path $PROFILE -Value "`r`n# shot-for-claude screenshot helpers`r`n$line"
    Write-Host "Added loader to your PowerShell profile: $PROFILE" -ForegroundColor Green
} else {
    Write-Host "Profile already loads shot-for-claude — skipped." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Done. Open a NEW PowerShell terminal, then try:" -ForegroundColor Cyan
Write-Host "  Win+Shift+S to capture, then run:  shot" -ForegroundColor Cyan
Write-Host "  Live capture feed (Ctrl+C to stop): shot-watch" -ForegroundColor Cyan
