#requires -version 5.1
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$muxx=Join-Path $root "muxx.ps1"
foreach($args in @(@("version"),@("help"),@("check","git"))){
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $muxx @args
    if($LASTEXITCODE -ne 0){throw "Smoke test failed: $($args -join ' ')"}
}
Write-Host "✅ Smoke tests completed." -ForegroundColor Green
