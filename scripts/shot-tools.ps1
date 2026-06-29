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
#   shot-save         move shots from the temp folder into your vault, then print
#                     their paths and markdown embeds
#                       shot-save all            move every saved shot
#                       shot-save <name...>      move only the named shots
#   shot-save-config  set/show the vault destination folder
#                       shot-save-config             show current destination
#                       shot-save-config '<path>'    set destination (-Create to mkdir)

$script:ShotDir            = Join-Path $env:USERPROFILE '.claude\shots'
$script:ShotSaveConfigPath = Join-Path $env:USERPROFILE '.claude\shot-save.config.json'

# Internal path resolvers. Wrapped in functions so tests can redirect them to a
# sandbox via Pester mocks and never touch the real profile.
function Get-ShotSaveDir        { $script:ShotDir }
function Get-ShotSaveConfigPath { $script:ShotSaveConfigPath }

# Read the persisted vault destination. Returns $null when unset or unreadable;
# a corrupt config is treated as "not set" rather than throwing.
function Get-ShotSaveVaultDir {
    $cfg = Get-ShotSaveConfigPath
    if (-not (Test-Path -LiteralPath $cfg)) { return $null }
    try {
        $obj = Get-Content -LiteralPath $cfg -Raw | ConvertFrom-Json
        if ($obj -and $obj.VaultDir) { return [string]$obj.VaultDir }
    } catch { return $null }
    return $null
}

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

function shot-save-config {
    # Set or show the vault destination folder that `shot-save` moves shots into.
    #   shot-save-config            -> print the current destination
    #   shot-save-config '<path>'   -> persist the destination (folder must exist,
    #                                  unless -Create is passed to make it)
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][string]$Path,
        [switch]$Create
    )

    $cfg = Get-ShotSaveConfigPath

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $vault = Get-ShotSaveVaultDir
        if ($vault) {
            Write-Host "shot-save destination: $vault" -ForegroundColor Green
            if (-not (Test-Path -LiteralPath $vault -PathType Container)) {
                Write-Host "  (warning: this folder no longer exists)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "shot-save destination not set. Set one with: shot-save-config '<path>'" -ForegroundColor Yellow
        }
        return
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        if ($Create) {
            New-Item -ItemType Directory -Path $Path -Force -ErrorAction SilentlyContinue | Out-Null
            # New-Item -ItemType Directory on a path that already exists as a FILE
            # is a no-op (and doesn't error), so re-verify we actually have a folder.
            if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
                Write-Host "shot-save-config: '$Path' is not a folder (a file may already exist at that path)." -ForegroundColor Red
                return
            }
        } else {
            Write-Host "shot-save-config: '$Path' does not exist or is not a folder. Create it first, or pass -Create." -ForegroundColor Red
            return
        }
    }

    $full = (Resolve-Path -LiteralPath $Path).Path

    # The destination must not be the temporary shots folder itself — that would turn
    # every move into an in-place rename and let the 100-file prune delete keepers.
    $shotDirNorm = [System.IO.Path]::GetFullPath((Get-ShotSaveDir)).TrimEnd('\')
    if ($full.TrimEnd('\') -ieq $shotDirNorm) {
        Write-Host "shot-save-config: the destination can't be the temporary shots folder itself." -ForegroundColor Red
        return
    }

    $cfgDir = Split-Path -Parent $cfg
    if ($cfgDir -and -not (Test-Path -LiteralPath $cfgDir)) {
        New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null
    }
    [pscustomobject]@{ VaultDir = $full } | ConvertTo-Json | Set-Content -LiteralPath $cfg -Encoding UTF8

    Write-Host "shot-save destination set to: $full" -ForegroundColor Green
}

# Pick a destination path that does not clobber an existing file: shot-X.png ->
# shot-X-1.png -> shot-X-2.png ... until a free name is found.
function Get-ShotSaveCollisionFreePath {
    param(
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][string]$FileName
    )
    $base = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $ext  = [System.IO.Path]::GetExtension($FileName)
    $dest = Join-Path $Directory $FileName
    $n = 1
    while (Test-Path -LiteralPath $dest) {
        $dest = Join-Path $Directory ("{0}-{1}{2}" -f $base, $n, $ext)
        $n++
    }
    return $dest
}

function shot-save {
    # Move saved shots out of the temp folder into the configured vault, then print
    # the moved files as a list of paths and a list of markdown embeds.
    #   shot-save all          move every shot-*.png
    #   shot-save <name...>    move only the named shots (bare filenames only)
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Targets
    )

    $vault = Get-ShotSaveVaultDir
    if (-not $vault) {
        Write-Host "shot-save: no destination configured. Set one with: shot-save-config '<path>'" -ForegroundColor Red
        return
    }
    if (-not (Test-Path -LiteralPath $vault -PathType Container)) {
        Write-Host "shot-save: destination '$vault' does not exist. Reconfigure with shot-save-config." -ForegroundColor Red
        return
    }

    if (-not $Targets -or $Targets.Count -eq 0) {
        Write-Host "shot-save: specify 'all' or one or more shot names, e.g. shot-save all" -ForegroundColor Yellow
        return
    }

    # 'all' is a reserved keyword and must stand alone — guard the easy mistake of
    # `shot-save all somename`, which would otherwise route to names-mode confusingly.
    if ($Targets.Count -gt 1 -and ($Targets -contains 'all')) {
        Write-Host "shot-save: 'all' moves every shot and must be used by itself." -ForegroundColor Yellow
        return
    }

    $shotDir = Get-ShotSaveDir
    if (-not (Test-Path -LiteralPath $shotDir -PathType Container)) {
        Write-Host "shot-save: nothing to move." -ForegroundColor Yellow
        return
    }
    $shotDirFull = (Resolve-Path -LiteralPath $shotDir).Path

    $files = @()
    if ($Targets.Count -eq 1 -and $Targets[0] -eq 'all') {
        # -Filter also matches 8.3 short names (e.g. shot-x.pngbak -> SHOT-X~1.PNG),
        # so re-assert the pattern on the real name, and skip reparse points so a
        # symlink/junction planted in the shots folder is never relocated.
        $files = @(Get-ChildItem -LiteralPath $shotDir -Filter 'shot-*.png' -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -like 'shot-*.png' -and
                -not ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
            })
        if ($files.Count -eq 0) {
            Write-Host "shot-save: nothing to move." -ForegroundColor Yellow
            return
        }
    } else {
        $missing = @()
        foreach ($name in $Targets) {
            # Security: a target is a bare filename within the shots folder only.
            # Reject path separators, parent-dir traversal, and rooted/absolute paths.
            if ($name -match '[\\/]' -or $name -match '\.\.' -or [System.IO.Path]::IsPathRooted($name)) {
                Write-Host "shot-save: invalid name '$name' (use a bare shot filename, not a path)." -ForegroundColor Red
                continue
            }
            $leaf = $name
            if ($leaf -notmatch '\.png$') { $leaf = "$leaf.png" }
            if ($leaf -notlike 'shot-*.png') {
                Write-Host "shot-save: '$name' is not a shot-*.png file; skipped." -ForegroundColor Red
                continue
            }
            $candidate = Join-Path $shotDir $leaf
            if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                $missing += $name
                continue
            }
            # Defense in depth: confirm the resolved file is a direct child of ShotDir.
            $resolved  = (Resolve-Path -LiteralPath $candidate).Path
            $parentDir = Split-Path -Parent $resolved
            if ($parentDir -ne $shotDirFull) {
                Write-Host "shot-save: '$name' resolved outside the shots folder; skipped." -ForegroundColor Red
                continue
            }
            $item = Get-Item -LiteralPath $candidate
            # Skip symlinks/junctions: Resolve-Path doesn't dereference them, so moving
            # one would relocate a link pointing at an arbitrary target.
            if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                Write-Host "shot-save: '$name' is a reparse point (symlink/junction); skipped." -ForegroundColor Red
                continue
            }
            $files += $item
        }
        foreach ($m in $missing) {
            Write-Host "shot-save: '$m' not found in the shots folder." -ForegroundColor Yellow
        }
        if ($files.Count -eq 0) {
            Write-Host "shot-save: no matching shots to move." -ForegroundColor Red
            return
        }
    }

    $moved  = @()
    $failed = @()
    foreach ($f in $files) {
        $dest = Get-ShotSaveCollisionFreePath -Directory $vault -FileName $f.Name
        try {
            # -ErrorAction Stop so a non-terminating Move-Item error (locked file,
            # permission denied, cross-volume/disk-full, a name that became occupied
            # after the collision check) is caught here instead of being silently
            # reported as a successful move.
            Move-Item -LiteralPath $f.FullName -Destination $dest -ErrorAction Stop
            $moved += $dest
        } catch {
            $failed += $f.Name
            Write-Host "shot-save: failed to move '$($f.Name)': $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    if ($moved.Count -eq 0) {
        Write-Host "shot-save: no files were moved." -ForegroundColor Red
        return
    }

    Write-Host "shot-save: moved $($moved.Count) screenshot(s) to $vault" -ForegroundColor Green
    if ($failed.Count -gt 0) {
        Write-Host "shot-save: $($failed.Count) file(s) could not be moved and remain in the shots folder." -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "File paths:" -ForegroundColor Cyan
    foreach ($p in $moved) { Write-Host $p }
    Write-Host ""
    Write-Host "Markdown embeds:" -ForegroundColor Cyan
    # Angle-bracket form so paths containing spaces still render in CommonMark/Obsidian.
    foreach ($p in $moved) { Write-Host ("![](<{0}>)" -f $p) }
}
