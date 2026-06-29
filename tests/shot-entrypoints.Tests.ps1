# tests/shot-entrypoints.Tests.ps1
# Integration tests for the standalone *.ps1 entry points (shot.ps1, shot-watch.ps1,
# shot-clear.ps1, shot-save.ps1, shot-save-config.ps1). They verify each thin wrapper
# dot-sources the shared library and forwards its arguments to the right command.
#
# Strategy: point $env:USERPROFILE at a temp sandbox so the commands' ShotDir/config
# resolve there and never touch the real ~/.claude. Run with Pester 5+.

BeforeAll {
    $script:ScriptsDir      = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts'
    $script:OrigUserProfile = $env:USERPROFILE
    $script:Commands        = 'shot', 'shot-watch', 'shot-clear', 'shot-save', 'shot-save-config'

    function New-Sandbox {
        $sb = Join-Path ([System.IO.Path]::GetTempPath()) ("shot-test-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path (Join-Path $sb '.claude\shots') -Force | Out-Null
        return $sb
    }
}

AfterAll {
    $env:USERPROFILE = $script:OrigUserProfile
}

Describe 'entry-point scripts are present and wired to the library' {
    It 'has a standalone entry point for every command' {
        foreach ($name in $script:Commands) {
            Join-Path $script:ScriptsDir "$name.ps1" | Should -Exist
        }
    }
    It 'dot-sources shot-tools.ps1 in every entry point' {
        foreach ($name in $script:Commands) {
            (Get-Content (Join-Path $script:ScriptsDir "$name.ps1") -Raw) | Should -Match 'shot-tools\.ps1'
        }
    }
}

Describe 'shot-clear.ps1' {
    BeforeEach {
        $script:Sandbox  = New-Sandbox
        $env:USERPROFILE = $script:Sandbox
        1..3 | ForEach-Object {
            Set-Content -Path (Join-Path $script:Sandbox ".claude\shots\shot-2026010$_-000000.png") -Value 'x'
        }
    }
    AfterEach {
        $env:USERPROFILE = $script:OrigUserProfile
        Remove-Item -LiteralPath $script:Sandbox -Recurse -Force -ErrorAction SilentlyContinue
    }
    It 'removes all shots with -Force (forwards the switch)' {
        & (Join-Path $script:ScriptsDir 'shot-clear.ps1') -Force
        (Get-ChildItem (Join-Path $script:Sandbox '.claude\shots') -Filter 'shot-*.png').Count | Should -Be 0
    }
}

Describe 'shot-save-config.ps1 + shot-save.ps1' {
    BeforeEach {
        $script:Sandbox  = New-Sandbox
        $script:Vault    = Join-Path $script:Sandbox 'vault'
        New-Item -ItemType Directory -Path $script:Vault -Force | Out-Null
        $env:USERPROFILE = $script:Sandbox
    }
    AfterEach {
        $env:USERPROFILE = $script:OrigUserProfile
        Remove-Item -LiteralPath $script:Sandbox -Recurse -Force -ErrorAction SilentlyContinue
    }
    It 'persists the destination (forwards the path argument)' {
        & (Join-Path $script:ScriptsDir 'shot-save-config.ps1') $script:Vault
        Join-Path $script:Sandbox '.claude\shot-save.config.json' | Should -Exist
    }
    It 'moves shots into the configured vault (forwards "all")' {
        & (Join-Path $script:ScriptsDir 'shot-save-config.ps1') $script:Vault
        Set-Content -Path (Join-Path $script:Sandbox '.claude\shots\shot-20260101-000000.png') -Value 'x'
        & (Join-Path $script:ScriptsDir 'shot-save.ps1') all
        (Get-ChildItem $script:Vault -Filter 'shot-*.png').Count | Should -Be 1
    }
}

Describe 'shot-watch.ps1' {
    BeforeEach {
        $script:Sandbox  = New-Sandbox
        $env:USERPROFILE = $script:Sandbox
    }
    AfterEach {
        $env:USERPROFILE = $script:OrigUserProfile
        Remove-Item -LiteralPath $script:Sandbox -Recurse -Force -ErrorAction SilentlyContinue
    }
    It 'runs a bounded session and exits cleanly (forwards start -MaxSeconds)' {
        { & (Join-Path $script:ScriptsDir 'shot-watch.ps1') start -MaxSeconds 1 } | Should -Not -Throw
    }
}
