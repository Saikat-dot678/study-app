$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host 'Preparing Windows desktop build...' -ForegroundColor Cyan
flutter config --enable-windows-desktop | Out-Host

if (-not (Test-Path 'windows/CMakeLists.txt')) {
  flutter create --platforms=windows . | Out-Host
}

flutter pub get | Out-Host
flutter analyze | Out-Host
flutter test | Out-Host
flutter build windows --release | Out-Host

Write-Host 'Windows build created under build/windows/x64/runner/Release' -ForegroundColor Green
