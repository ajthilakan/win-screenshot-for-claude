# Pester v5 tests for shot-save / shot-save-config.
# Fully sandboxed: the script's path resolvers are mocked to temp directories,
# so no test ever reads or writes the real ~/.claude profile.
#
# Run:  Invoke-Pester tests/shot-save.Tests.ps1

BeforeAll {
    . (Join-Path $PSScriptRoot '..\scripts\shot-tools.ps1')

    function New-FakeShot {
        param([string]$Dir, [string]$Name)
        # A tiny non-empty file is enough — these tests assert on paths/moves,
        # not image contents.
        Set-Content -LiteralPath (Join-Path $Dir $Name) -Value 'PNG' -Encoding Byte -ErrorAction SilentlyContinue
        if (-not (Test-Path -LiteralPath (Join-Path $Dir $Name))) {
            [System.IO.File]::WriteAllBytes((Join-Path $Dir $Name), [byte[]](137,80,78,71))
        }
    }
}

Describe 'shot-save-config' {
    BeforeEach {
        $script:tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("shotcfg-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:tmpRoot -Force | Out-Null
        $script:tmpCfg = Join-Path $script:tmpRoot 'shot-save.config.json'
        Mock -CommandName Get-ShotSaveConfigPath -MockWith { $script:tmpCfg }
        $script:WH = New-Object System.Collections.Generic.List[string]
        Mock -CommandName Write-Host -MockWith { $script:WH.Add([string]$Object) }
    }
    AfterEach {
        Remove-Item -LiteralPath $script:tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'persists a valid existing directory as an absolute path' {
        $vault = Join-Path $script:tmpRoot 'vault'
        New-Item -ItemType Directory -Path $vault -Force | Out-Null

        shot-save-config $vault

        Test-Path -LiteralPath $script:tmpCfg | Should -BeTrue
        (Get-ShotSaveVaultDir) | Should -Be ((Resolve-Path -LiteralPath $vault).Path)
    }

    It 'shows the stored path when called with no argument' {
        $vault = Join-Path $script:tmpRoot 'vault'
        New-Item -ItemType Directory -Path $vault -Force | Out-Null
        shot-save-config $vault
        $script:WH.Clear()

        shot-save-config

        ($script:WH -join "`n") | Should -Match ([regex]::Escape((Resolve-Path -LiteralPath $vault).Path))
    }

    It 'reports "not set" before any destination is configured (no throw)' {
        { shot-save-config } | Should -Not -Throw
        ($script:WH -join "`n") | Should -Match 'not set'
    }

    It 'refuses a non-existent directory without -Create and writes no config' {
        $missing = Join-Path $script:tmpRoot 'does-not-exist'

        shot-save-config $missing

        Test-Path -LiteralPath $script:tmpCfg | Should -BeFalse
        ($script:WH -join "`n") | Should -Match 'does not exist'
    }

    It 'creates the directory and persists it when -Create is passed' {
        $missing = Join-Path $script:tmpRoot 'made-by-create'

        shot-save-config $missing -Create

        Test-Path -LiteralPath $missing -PathType Container | Should -BeTrue
        (Get-ShotSaveVaultDir) | Should -Be ((Resolve-Path -LiteralPath $missing).Path)
    }

    It 'treats a corrupt config file as "not set" (returns null, no throw)' {
        Set-Content -LiteralPath $script:tmpCfg -Value '{ this is not json' -Encoding UTF8
        { Get-ShotSaveVaultDir } | Should -Not -Throw
        (Get-ShotSaveVaultDir) | Should -BeNullOrEmpty
    }
}

Describe 'shot-save' {
    BeforeEach {
        $script:tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("shotmv-" + [guid]::NewGuid().ToString('N'))
        $script:tShot = Join-Path $script:tmpRoot 'shots'
        $script:tVault = Join-Path $script:tmpRoot 'My Vault'   # space is intentional
        New-Item -ItemType Directory -Path $script:tShot  -Force | Out-Null
        New-Item -ItemType Directory -Path $script:tVault -Force | Out-Null

        Mock -CommandName Get-ShotSaveDir      -MockWith { $script:tShot }
        Mock -CommandName Get-ShotSaveVaultDir -MockWith { $script:tVault }

        $script:WH = New-Object System.Collections.Generic.List[string]
        Mock -CommandName Write-Host -MockWith { $script:WH.Add([string]$Object) }
    }
    AfterEach {
        Remove-Item -LiteralPath $script:tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'moves every shot in "all" mode and empties the temp folder' {
        New-FakeShot $script:tShot 'shot-A.png'
        New-FakeShot $script:tShot 'shot-B.png'
        New-FakeShot $script:tShot 'shot-C.png'

        shot-save all

        (Get-ChildItem -LiteralPath $script:tShot -Filter 'shot-*.png').Count | Should -Be 0
        (Get-ChildItem -LiteralPath $script:tVault -Filter 'shot-*.png').Count | Should -Be 3
    }

    It 'moves only the named shots and leaves the rest' {
        New-FakeShot $script:tShot 'shot-A.png'
        New-FakeShot $script:tShot 'shot-B.png'
        New-FakeShot $script:tShot 'shot-C.png'

        shot-save 'shot-A.png' 'shot-B.png'

        Test-Path -LiteralPath (Join-Path $script:tShot 'shot-C.png') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:tVault 'shot-A.png') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:tVault 'shot-B.png') | Should -BeTrue
    }

    It 'accepts a name without the .png extension' {
        New-FakeShot $script:tShot 'shot-A.png'

        shot-save 'shot-A'

        Test-Path -LiteralPath (Join-Path $script:tVault 'shot-A.png') | Should -BeTrue
    }

    It 'auto-renames on collision and never overwrites the existing vault file' {
        New-FakeShot $script:tShot 'shot-A.png'
        Set-Content -LiteralPath (Join-Path $script:tVault 'shot-A.png') -Value 'ORIGINAL' -Encoding UTF8

        shot-save 'shot-A.png'

        (Get-Content -LiteralPath (Join-Path $script:tVault 'shot-A.png') -Raw).Trim() | Should -Be 'ORIGINAL'
        Test-Path -LiteralPath (Join-Path $script:tVault 'shot-A-1.png') | Should -BeTrue
    }

    It 'emits markdown embeds in angle-bracket form so spaced paths render' {
        New-FakeShot $script:tShot 'shot-A.png'

        shot-save all

        $embed = $script:WH | Where-Object { $_.StartsWith('![](') }
        $embed | Should -Not -BeNullOrEmpty
        ($embed -join "`n") | Should -Match '^\!\[\]\(<.*>\)$'
        ($embed -join "`n") | Should -Match ([regex]::Escape('My Vault'))
    }

    It 'errors and moves nothing when no destination is configured' {
        Mock -CommandName Get-ShotSaveVaultDir -MockWith { $null }
        New-FakeShot $script:tShot 'shot-A.png'

        shot-save all

        Test-Path -LiteralPath (Join-Path $script:tShot 'shot-A.png') | Should -BeTrue
        ($script:WH -join "`n") | Should -Match 'no destination configured'
    }

    It 'errors when the configured destination no longer exists' {
        Remove-Item -LiteralPath $script:tVault -Recurse -Force
        New-FakeShot $script:tShot 'shot-A.png'

        shot-save all

        Test-Path -LiteralPath (Join-Path $script:tShot 'shot-A.png') | Should -BeTrue
        ($script:WH -join "`n") | Should -Match 'does not exist'
    }

    It 'reports nothing to move when the temp folder is empty' {
        shot-save all
        ($script:WH -join "`n") | Should -Match 'nothing to move'
    }

    It 'reports a per-name miss but still moves the names that exist' {
        New-FakeShot $script:tShot 'shot-A.png'

        shot-save 'shot-A.png' 'shot-missing.png'

        Test-Path -LiteralPath (Join-Path $script:tVault 'shot-A.png') | Should -BeTrue
        ($script:WH -join "`n") | Should -Match "not found"
    }

    It 'rejects path-traversal and absolute-path names and moves nothing' {
        New-FakeShot $script:tShot 'shot-A.png'

        shot-save '..\..\secret.txt'
        shot-save 'C:\Windows\System32\drivers\etc\hosts'
        shot-save 'sub\shot-A.png'

        (Get-ChildItem -LiteralPath $script:tVault -File -ErrorAction SilentlyContinue).Count | Should -Be 0
        ($script:WH -join "`n") | Should -Match 'invalid name'
    }

    It 'never moves a non-shot file in "all" mode' {
        New-FakeShot $script:tShot 'shot-A.png'
        Set-Content -LiteralPath (Join-Path $script:tShot 'notes.txt') -Value 'secret' -Encoding UTF8

        shot-save all

        Test-Path -LiteralPath (Join-Path $script:tShot 'notes.txt') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:tVault 'notes.txt') | Should -BeFalse
    }
}
