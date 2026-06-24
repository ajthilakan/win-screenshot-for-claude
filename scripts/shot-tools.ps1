# shot-tools.ps1
# Clipboard -> file screenshot helpers for Claude Code on Windows.
# Why: Claude Code can't read raw clipboard images on Windows, but it reads
# images by file PATH reliably. These helpers turn a Win+Shift+S capture into
# a saved PNG and put its path on the clipboard so you can paste the path.
#
# Commands:
#   shot              capture clipboard image -> PNG, copy path to clipboard
#   shot-watch        live feed: prints + copies the path for each capture
#                     (Win+Shift+S as many times as you like; Ctrl+C to stop)
#   shot-clear        delete all saved screenshots (prompts; -Force to skip)

$script:ShotDir = Join-Path $env:USERPROFILE '.claude\shots'

function Save-ClipboardShot {
    [CmdletBinding()]
    param([switch]$Quiet)

    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    if (-not (Test-Path $script:ShotDir)) {
        New-Item -ItemType Directory -Path $script:ShotDir -Force | Out-Null
    }

    $img = $null
    try { $img = Get-Clipboard -Format Image } catch {}
    if ($null -eq $img) {
        if (-not $Quiet) {
            Write-Host "shot: no image on the clipboard. Capture with Win+Shift+S first." -ForegroundColor Yellow
        }
        return $null
    }

    $name = "shot-{0}.png" -f (Get-Date -Format 'yyyyMMdd-HHmmss')
    $path = Join-Path $script:ShotDir $name
    $img.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $img.Dispose()
    Set-Clipboard -Value $path

    # Keep the folder tidy: retain the 100 most recent shots.
    Get-ChildItem $script:ShotDir -Filter 'shot-*.png' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip 100 |
        Remove-Item -Force -ErrorAction SilentlyContinue

    if (-not $Quiet) {
        Write-Host "shot saved (path copied to clipboard):" -ForegroundColor Green
    }
    # Emit the bare path on its own line so Claude Code's `!shot` picks it up.
    return $path
}

Set-Alias shot Save-ClipboardShot

function shot-clear {
    [CmdletBinding()]
    param([switch]$Force)

    if (-not (Test-Path $script:ShotDir)) {
        Write-Host "shot-clear: nothing to remove." -ForegroundColor Yellow
        return
    }
    $files = @(Get-ChildItem $script:ShotDir -Filter 'shot-*.png' -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) {
        Write-Host "shot-clear: nothing to remove." -ForegroundColor Yellow
        return
    }
    if (-not $Force) {
        $ans = Read-Host "Delete $($files.Count) screenshot(s) from $script:ShotDir? (y/N)"
        if ($ans -notmatch '^(y|yes)$') {
            Write-Host "shot-clear: cancelled." -ForegroundColor Yellow
            return
        }
    }
    $files | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host "shot-clear: removed $($files.Count) screenshot(s)." -ForegroundColor Green
}

function shot-watch {
    # Live foreground feed: watches the clipboard and, for each NEW capture,
    # saves a PNG, copies its path to the clipboard, and PRINTS the path so you
    # have a running list to grab any of them from. Ctrl+C to stop.
    # -MaxSeconds is for bounded/test runs (0 = run until Ctrl+C).
    # An optional first word ('on'/'start') is accepted for muscle memory.
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][string]$Action,
        [int]$MaxSeconds = 0
    )

    if ($Action -and $Action -match '^(off|stop)$') {
        Write-Host "shot-watch now runs live in the foreground - press Ctrl+C in the watch terminal to stop it." -ForegroundColor Yellow
        return
    }
    if ($Action -and $Action -notmatch '^(on|start)$') {
        Write-Host "shot-watch: ignoring unknown argument '$Action' - starting the live feed." -ForegroundColor DarkGray
    }

    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    if (-not (Test-Path $script:ShotDir)) {
        New-Item -ItemType Directory -Path $script:ShotDir -Force | Out-Null
    }

    Write-Host "shot-watch live - Win+Shift+S to capture, Ctrl+C to stop." -ForegroundColor Green
    Write-Host "Each capture is saved, its path is printed below and copied to your clipboard." -ForegroundColor DarkGray

    $sha = [System.Security.Cryptography.SHA1]::Create()
    $lastHash = ''
    $start = Get-Date
    $count = 0
    try {
        while ($true) {
            if ($MaxSeconds -gt 0 -and ((Get-Date) - $start).TotalSeconds -ge $MaxSeconds) { break }

            $img = $null
            try { $img = Get-Clipboard -Format Image } catch {}
            if ($null -ne $img) {
                $ms = New-Object System.IO.MemoryStream
                $img.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
                $bytes = $ms.ToArray()
                $ms.Dispose()
                $img.Dispose()

                $hash = [BitConverter]::ToString($sha.ComputeHash($bytes))
                if ($hash -ne $lastHash) {
                    $lastHash = $hash
                    $name = "shot-{0}.png" -f (Get-Date -Format 'yyyyMMdd-HHmmss')
                    $path = Join-Path $script:ShotDir $name
                    [System.IO.File]::WriteAllBytes($path, $bytes)
                    Set-Clipboard -Value $path

                    Get-ChildItem $script:ShotDir -Filter 'shot-*.png' |
                        Sort-Object LastWriteTime -Descending |
                        Select-Object -Skip 100 |
                        Remove-Item -Force -ErrorAction SilentlyContinue

                    $count++
                    Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $path) -ForegroundColor Cyan
                }
            } else {
                # No image on the clipboard (e.g. we just replaced it with the
                # path, or you copied text). Reset so the next capture registers.
                $lastHash = ''
            }
            Start-Sleep -Milliseconds 700
        }
    } finally {
        Write-Host "shot-watch stopped ($count capture(s) this session)." -ForegroundColor Yellow
    }
}
