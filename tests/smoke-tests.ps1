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
Copy-Item (Join-Path $root "muxx.ps1") (Join-Path $tmp "muxx.ps1")
Copy-Item (Join-Path $root "help.txt") (Join-Path $tmp "help.txt")
Copy-Item (Join-Path $root "src\*.ps1") (Join-Path $tmp "src")
& (Join-Path $tmp "muxx.cmd") help
if($LASTEXITCODE -ne 0){throw "Smoke test failed: muxx.cmd help"}

# Package-less special cases must stop before the generic Winget path.
. (Join-Path $root "src\installer.ps1")
function Test-MuxxWinget { throw "Winget must not be called for package-less tools" }
foreach($tool in @(
    @{Id="npm";Name="npm";WingetId="";Website="https://nodejs.org/"},
    @{Id="curl";Name="Curl";WingetId="";Website="https://curl.se/windows/"}
)){
    $result=Install-MuxxTool -Tool $tool -AssumeYes
    if($result -ne $false){throw "Package-less install test failed: $($tool.Id)"}
}

$pass=[char]0x2713
Write-Host "$pass Smoke tests completed." -ForegroundColor Green
