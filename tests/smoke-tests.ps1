#requires -version 5.1
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$muxx=Join-Path $root "muxx.ps1"
foreach($args in @(@("version"),@("help"),@("check","git"))){
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $muxx @args
    if($LASTEXITCODE -ne 0){throw "Smoke test failed: $($args -join ' ')"}
}
$tmp=Join-Path $env:TEMP "muxx-smoke"
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path (Join-Path $tmp "src") -Force|Out-Null
Copy-Item (Join-Path $root "muxx.cmd") (Join-Path $tmp "muxx.cmd")
Copy-Item (Join-Path $root "muxx.ps1") (Join-Path $tmp "muxx-core.ps1")
Copy-Item (Join-Path $root "help.txt") (Join-Path $tmp "help.txt")
Copy-Item (Join-Path $root "src\*.ps1") (Join-Path $tmp "src")
& (Join-Path $tmp "muxx.cmd") help
if($LASTEXITCODE -ne 0){throw "Smoke test failed: muxx.cmd help"}
Write-Host "✅ Smoke tests completed." -ForegroundColor Green
