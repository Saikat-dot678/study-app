$ErrorActionPreference = 'Stop'

function Invoke-Flutter {
  & flutter @args | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "Flutter failed ($LASTEXITCODE): $args" }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host 'Preparing Study for Windows desktop...' -ForegroundColor Cyan
Invoke-Flutter config --enable-windows-desktop | Out-Host

if (-not (Test-Path 'windows/CMakeLists.txt')) {
  Write-Host 'Generating the Flutter Windows runner...' -ForegroundColor DarkCyan
  Invoke-Flutter create --platforms=windows . | Out-Host
}

& .\tool\patch_windows_cmake.ps1
Invoke-Flutter pub get
Write-Host 'Launching Study on Windows...' -ForegroundColor Green
Invoke-Flutter run -d windows
