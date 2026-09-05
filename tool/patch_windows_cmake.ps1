$ErrorActionPreference = 'Stop'

$cmakePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'windows\CMakeLists.txt'
if (-not (Test-Path $cmakePath)) {
  throw "Windows runner is missing. Run 'flutter create --platforms=windows .' first."
}

$content = Get-Content $cmakePath -Raw
$define = 'add_compile_definitions(_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)'

if ($content -notmatch [regex]::Escape($define)) {
  $projectPattern = '(project\([^\r\n]+\)\r?\n)'
  if ($content -notmatch $projectPattern) {
    throw 'Could not locate the project() line in windows/CMakeLists.txt.'
  }
  $content = [regex]::Replace(
    $content,
    $projectPattern,
    ('$1' + "`r`n# just_audio_windows currently uses Microsoft's experimental coroutine shim.`r`n# VS 2026 turns that deprecation into an error unless explicitly acknowledged.`r`n$define`r`n"),
    1
  )
  Set-Content -Path $cmakePath -Value $content -Encoding utf8
  Write-Host 'Applied Windows coroutine compatibility define.' -ForegroundColor DarkCyan
}
