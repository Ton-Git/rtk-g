# Phase 4 - Windows installer

## Goal

Add `/home/runner/work/rtk-g/rtk-g/install.ps1` as the Windows-native installer counterpart to `/home/runner/work/rtk-g/rtk-g/install.sh`.

## Why this phase exists

The current installer is shell-only and explicitly Linux/macOS oriented. Windows users can download release assets manually today, but there is no first-class automated install path.

## Files involved in the implementation PR

- add `/home/runner/work/rtk-g/rtk-g/install.ps1`
- keep `/home/runner/work/rtk-g/rtk-g/install.sh` unchanged

## Current reference

- `/home/runner/work/rtk-g/rtk-g/install.sh`

## Recommended installer shape

```powershell
param(
    [string]$InstallDir = "$HOME\.local\bin"
)

$ErrorActionPreference = "Stop"
$Repo = "Ton-Git/rtk-g"
$BinaryName = "rtk.exe"

function Info($Message) { Write-Host "[INFO] $Message" -ForegroundColor Green }
function Warn($Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Fail($Message) { throw $Message }

function Get-Arch {
    switch ($env:PROCESSOR_ARCHITECTURE) {
        "AMD64" { return "x86_64" }
        "ARM64" { return "aarch64" }
        default { Fail "Unsupported architecture: $env:PROCESSOR_ARCHITECTURE" }
    }
}

function Get-LatestTag {
    $release = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest"
    if (-not $release.tag_name) { Fail "Failed to resolve latest release tag" }
    return $release.tag_name
}

function Install-Rtk {
    $arch = Get-Arch
    $tag = Get-LatestTag
    $asset = if ($arch -eq "x86_64") {
        "rtk-x86_64-pc-windows-msvc.zip"
    } else {
        "rtk-aarch64-pc-windows-msvc.zip"
    }

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("rtk-install-" + [guid]::NewGuid())
    $zipPath = Join-Path $tempDir "rtk.zip"
    $downloadUrl = "https://github.com/$Repo/releases/download/$tag/$asset"

    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

    Info "Downloading $downloadUrl"
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath

    Info "Extracting archive"
    Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

    Move-Item -Force (Join-Path $tempDir "rtk.exe") (Join-Path $InstallDir "rtk.exe")
    Remove-Item -Recurse -Force $tempDir

    Info "Installed to $(Join-Path $InstallDir 'rtk.exe')"
}

function Test-Install {
    $binary = Join-Path $InstallDir "rtk.exe"
    if (-not (Test-Path $binary)) { Fail "Binary not found after install" }

    try {
        & $binary --version
    } catch {
        Warn "Installed successfully, but PATH may need updating."
        Warn "Add $InstallDir to your user PATH."
    }
}

Install-Rtk
Test-Install
```

## Notes for the real implementation

- Keep the PowerShell installer additive; do not change the Unix installer flow.
- Reuse the same release naming assumptions already documented in `/home/runner/work/rtk-g/rtk-g/README.md`.
- If this fork will not publish Windows ARM assets, handle that explicitly in the script output instead of silently failing.
- If release ownership changes, update the `$Repo` constant to match the repository that actually ships binaries.

## PATH guidance snippet for docs reuse

```powershell
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$InstallDir*") {
    Write-Host "Add $InstallDir to your user PATH, then restart your terminal."
}
```
