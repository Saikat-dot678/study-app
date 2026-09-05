$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host 'Preparing Study for Windows desktop...' -ForegroundColor Cyan
flutter config --enable-windows-desktop | Out-Host

if (-not (Test-Path 'windows/CMakeLists.txt')) {
  Write-Host 'Generating the Flutter Windows runner...' -ForegroundColor DarkCyan
  flutter create --platforms=windows . | Out-Host
}

powershell -ExecutionPolicy Bypass -File .\tool\patch_windows_cmake.ps1 | Out-Host
flutter pub get | Out-Host
Write-Host 'Launching Study on Windows...' -ForegroundColor Green
flutter run -d windows
