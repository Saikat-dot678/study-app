$ErrorActionPreference = 'Stop'

function Invoke-Flutter {
  & flutter @args | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "Flutter failed ($LASTEXITCODE): $args" }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host 'Preparing Windows desktop build...' -ForegroundColor Cyan
Invoke-Flutter config --enable-windows-desktop | Out-Host

if (-not (Test-Path 'windows/CMakeLists.txt')) {
  Invoke-Flutter create --platforms=windows . | Out-Host
}

& .\tool\patch_windows_cmake.ps1
Invoke-Flutter pub get
Invoke-Flutter analyze
Invoke-Flutter test
Invoke-Flutter build windows --release

Write-Host 'Windows build created under build/windows/x64/runner/Release' -ForegroundColor Green
