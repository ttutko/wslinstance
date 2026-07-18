# import.ps1 — import the airgapped Debian WSL instance on Windows.
# Run from this bundle directory in PowerShell:
#     powershell -ExecutionPolicy Bypass -File .\import.ps1
# Optional parameters let you override the distro name / install location.

param(
    [string]$DistroName = "@@DISTRO@@",
    [string]$InstallDir = "$env:LOCALAPPDATA\WSL\@@DISTRO@@",
    [string]$Tarball    = "@@TARBALL@@"
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$tarPath   = Join-Path $scriptDir $Tarball

Write-Host "Importing '$DistroName' from $Tarball ..." -ForegroundColor Cyan

if (-not (Test-Path $tarPath)) {
    throw "Tarball not found: $tarPath"
}

# Optional integrity check against SHA256SUMS.
$sumsFile = Join-Path $scriptDir "SHA256SUMS"
if (Test-Path $sumsFile) {
    $expected = (Get-Content $sumsFile | Select-Object -First 1).Split(" ")[0]
    $actual   = (Get-FileHash $tarPath -Algorithm SHA256).Hash.ToLower()
    if ($expected -ne $actual) {
        throw "Checksum mismatch! expected $expected got $actual"
    }
    Write-Host "Checksum OK." -ForegroundColor Green
}

if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
    $existing = (wsl.exe --list --quiet) -replace "`0",""
    if ($existing -contains $DistroName) {
        throw "A WSL distro named '$DistroName' already exists. Unregister it first: wsl --unregister $DistroName"
    }
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
wsl.exe --import $DistroName $InstallDir $tarPath --version 2

Write-Host ""
Write-Host "Done. Launch it with:" -ForegroundColor Green
Write-Host "    wsl -d $DistroName"
Write-Host ""
Write-Host "On first launch a short wizard will configure your zsh options."
Write-Host "Run 'wsltools' or 'man wsltools' to see everything that's installed,"
Write-Host "and 'wsl-selftest' to re-verify all tools work offline."
