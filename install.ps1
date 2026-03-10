param(
    [string]$InstallDir = "$HOME\.local\bin"
)

$ErrorActionPreference = "Stop"

$Repo = "Ton-Git/rtk-g"
$BinaryName = "rtk.exe"

function Write-Info([string]$Message) {
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn([string]$Message) {
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Fail([string]$Message) {
    throw $Message
}

function Get-TargetAsset {
    switch ($env:PROCESSOR_ARCHITECTURE) {
        "AMD64" { return "rtk-x86_64-pc-windows-msvc.zip" }
        default { Fail "Unsupported Windows architecture: $env:PROCESSOR_ARCHITECTURE" }
    }
}

function Get-LatestTag {
    $release = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest"
    if (-not $release.tag_name) {
        Fail "Failed to resolve latest release tag"
    }
    return $release.tag_name
}

function Install-Rtk {
    $asset = Get-TargetAsset
    $tag = Get-LatestTag
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("rtk-install-" + [guid]::NewGuid())
    $zipPath = Join-Path $tempDir "rtk.zip"
    $downloadUrl = "https://github.com/$Repo/releases/download/$tag/$asset"

    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

    Write-Info "Downloading $downloadUrl"
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath

    Write-Info "Extracting archive"
    Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

    Move-Item -Force (Join-Path $tempDir $BinaryName) (Join-Path $InstallDir $BinaryName)
    Remove-Item -Recurse -Force $tempDir

    Write-Info "Installed to $(Join-Path $InstallDir $BinaryName)"
}

function Verify-Install {
    $binary = Join-Path $InstallDir $BinaryName
    if (-not (Test-Path $binary)) {
        Fail "Binary not found after install"
    }

    Write-Info "Verification: $(& $binary --version)"

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$InstallDir*") {
        Write-Warn "Add $InstallDir to your user PATH, then restart your terminal."
    }
}

Install-Rtk
Verify-Install
