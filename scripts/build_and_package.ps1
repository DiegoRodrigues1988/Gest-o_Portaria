<#
Builds release binaries for Windows and Android, and packages them into a dist/ folder.

Usage:
  .\scripts\build_and_package.ps1 [-Platforms windows,android] [-Clean]

Examples:
  .\scripts\build_and_package.ps1 -Platforms windows,android
  .\scripts\build_and_package.ps1 -Platforms windows -Clean
#>

param(
    [ValidateSet('windows','android')]
    [string[]]$Platforms = @('windows'),

    [switch]$Clean
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $root

function Ensure-Dir([string]$path) {
    if (-Not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
    }
}

$distDir = Join-Path $root 'dist'
if ($Clean -and (Test-Path $distDir)) {
    Write-Host "Cleaning dist folder..."
    Remove-Item -Recurse -Force $distDir
}

Ensure-Dir $distDir

if ($Platforms -contains 'windows') {
    Write-Host "Building Windows release..."
    flutter build windows --release

    $winOutput = Join-Path $root 'build\windows\runner\Release'
    $winDist = Join-Path $distDir 'windows'
    Ensure-Dir $winDist

    Write-Host "Copying Windows artifacts to dist/windows..."
    Copy-Item -Path (Join-Path $winOutput '*') -Destination $winDist -Recurse -Force

    $zipPath = Join-Path $distDir 'gestao_portaria_windows.zip'
    if (Test-Path $zipPath) { Remove-Item $zipPath }
    Write-Host "Compressing Windows release to $zipPath..."
    Compress-Archive -Path (Join-Path $winDist '*') -DestinationPath $zipPath -Force
}

if ($Platforms -contains 'android') {
    Write-Host "Building Android release (APK)..."
    flutter build apk --release

    $apkOutput = Join-Path $root 'build\app\outputs\flutter-apk'
    $apkDist = Join-Path $distDir 'android'
    Ensure-Dir $apkDist

    Get-ChildItem -Path $apkOutput -Filter '*-release.apk' -File | ForEach-Object {
        Copy-Item $_.FullName -Destination $apkDist -Force
    }

    $zipPath = Join-Path $distDir 'gestao_portaria_android.zip'
    if (Test-Path $zipPath) { Remove-Item $zipPath }
    Write-Host "Compressing Android APKs to $zipPath..."
    Compress-Archive -Path (Join-Path $apkDist '*') -DestinationPath $zipPath -Force
}

Write-Host 'Build and packaging complete. See dist/ for artifacts.'
