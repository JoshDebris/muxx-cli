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
. (Join-Path $root "src\utils.ps1")
. (Join-Path $root "src\installer.ps1")
function Test-MuxxWinget { throw "Winget must not be called for package-less tools" }
foreach($tool in @(
    @{Id="npm";Name="npm";WingetId="";Website="https://nodejs.org/"},
    @{Id="curl";Name="Curl";WingetId="";Website="https://curl.se/windows/"}
)){
    $result=Install-MuxxTool -Tool $tool -AssumeYes
    if($result -ne $false){throw "Package-less install test failed: $($tool.Id)"}
}

# Winget's "already installed, no upgrade" result is successful for MUXX.
function Test-MuxxWinget { return $true }
function Update-MuxxSessionPath {}
function Add-MuxxUserPathEntry { return $true }
$script:wingetCalls=0
function Invoke-MuxxInteractiveProcess {
    $script:wingetCalls++
    return [pscustomobject]@{Success=$false;ExitCode=-1978335189;Error=""}
}
function Test-MuxxTool {
    return [pscustomobject]@{Installed=$true;Status="Installed";Name="jq";Version="1.7.1";Message=""}
}
function Write-MuxxToolResult {}
$jqResult=Install-MuxxTool -Tool @{Id="jq";Name="jq";WingetId="jqlang.jq";Website="https://jqlang.github.io/jq/download/"} -AssumeYes
if(-not $jqResult -or $script:wingetCalls -ne 1){throw "Winget already-installed handling failed"}

# A stale Winget registration must trigger a forced repair and real verification.
$script:wingetCalls=0
$script:toolChecks=0
$script:repairWasForced=$false
function Invoke-MuxxInteractiveProcess {
    param([string]$FilePath,[string[]]$Arguments)
    $script:wingetCalls++
    if($Arguments -contains "--force"){$script:repairWasForced=$true;return [pscustomobject]@{Success=$true;ExitCode=0;Error=""}}
    return [pscustomobject]@{Success=$false;ExitCode=-1978335189;Error=""}
}
function Test-MuxxTool {
    $script:toolChecks++
    return [pscustomobject]@{Installed=($script:toolChecks -gt 1);Status="Installed";Name="jq";Version="1.7.1";Message=""}
}
$jqRepairResult=Install-MuxxTool -Tool @{Id="jq";Name="jq";WingetId="jqlang.jq";Website="https://jqlang.github.io/jq/download/"} -AssumeYes
if(-not $jqRepairResult -or $script:wingetCalls -ne 2 -or -not $script:repairWasForced){
    throw "Stale Winget registration repair failed"
}

# `muxx install` must repair an installed tool that is missing from PATH.
. (Join-Path $root "src\commands.ps1")
$script:pathRepairCalled=$false
function Find-MuxxTool { return @{Id="jq";Name="jq";WingetId="jqlang.jq";Website="https://jqlang.github.io/jq/download/"} }
function Test-MuxxTool { return [pscustomobject]@{Installed=$true;Status="Warning";Name="jq";Version="1.8.2";Message="Installed, but not on PATH"} }
function Confirm-MuxxToolInstallation { $script:pathRepairCalled=$true;return $true }
function Install-MuxxTool { throw "Install-MuxxTool must not run for an installed tool" }
Invoke-MuxxInstallCommand -Arguments @("jq")
if(-not $script:pathRepairCalled){throw "Installed tool PATH repair was skipped"}

# Registry IDs and aliases must remain unique and all new tool groups resolvable.
. (Join-Path $root "src\checker.ps1")
. (Join-Path $root "src\registry.ps1")
$registry=@(Get-MuxxToolRegistry)
$keys=@($registry | ForEach-Object { @($_.Id) + @($_.Aliases) })
$duplicates=@($keys | Group-Object | Where-Object Count -gt 1)
if($duplicates.Count){throw "Duplicate registry IDs or aliases: $($duplicates.Name -join ', ')"}
foreach($id in @("pip","pipx","uv","poetry","cmake","ninja","make","msbuild","gcc","clang","choco","scoop")){
    if(-not(Find-MuxxTool $id)){throw "Registry lookup failed: $id"}
}

# Winget portable links must be recognized even when their directory is not on PATH.
$originalLocalAppData=$env:LOCALAPPDATA
$fakeLocalAppData=Join-Path $tmp "localappdata"
$fakeLinks=Join-Path $fakeLocalAppData "Microsoft\WinGet\Links"
New-Item -ItemType Directory -Path $fakeLinks -Force|Out-Null
Copy-Item "$env:SystemRoot\System32\where.exe" (Join-Path $fakeLinks "muxx-fixture.exe")
$env:LOCALAPPDATA=$fakeLocalAppData
try{
    $linked=Test-MuxxTool -Tool @{Id="fixture";Name="Fixture";Category="Test";Command="muxx-fixture";Args=@("/?");Pattern=""}
    if(-not $linked.Installed -or $linked.Status -ne "Warning" -or $linked.Message -ne "Installed, but not on PATH"){
        throw "Winget link detection failed"
    }
}finally{
    $env:LOCALAPPDATA=$originalLocalAppData
}

# Winget package contents must be found when alias creation failed.
$fakePackages=Join-Path $fakeLocalAppData "Microsoft\WinGet\Packages\Fixture.Tool_Microsoft.Winget.Source_test"
New-Item -ItemType Directory -Path $fakePackages -Force|Out-Null
Copy-Item "$env:SystemRoot\System32\where.exe" (Join-Path $fakePackages "fixture-tool.exe")
$env:LOCALAPPDATA=$fakeLocalAppData
try{
    $packaged=Test-MuxxTool -Tool @{Id="package-fixture";Name="Package Fixture";Category="Test";Command="fixture-tool";Args=@("/?");Pattern="";WingetId="Fixture.Tool"}
    if(-not $packaged.Installed -or $packaged.Status -ne "Warning" -or $packaged.Path -notlike "$fakePackages*"){
        throw "Winget package directory detection failed"
    }
}finally{
    $env:LOCALAPPDATA=$originalLocalAppData
}

$pass=[char]0x2713
Write-Host "$pass Smoke tests completed." -ForegroundColor Green
