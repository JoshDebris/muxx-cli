#requires -version 5.1
Set-StrictMode -Version 2.0
$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $root "src\utils.ps1")
. (Join-Path $root "src\checker.ps1")
. (Join-Path $root "src\registry.ps1")
$fixture=Join-Path ([IO.Path]::GetTempPath()) ("muxx-msbuild-"+[guid]::NewGuid().ToString("N"))
$originalProgramFilesX86=${env:ProgramFiles(x86)}
$script:pathCommand=$null
$script:calls=0
function Get-Command {
    param([string]$Name,$ErrorAction)
    if($Name -eq "MSBuild.exe"){return $script:pathCommand}
    Microsoft.PowerShell.Core\Get-Command $Name -ErrorAction SilentlyContinue
}
function Invoke-MuxxProcess {
    param([string]$FilePath,[string[]]$Arguments,[int]$TimeoutSeconds)
    $script:calls++
    if($Arguments -notcontains "*" -or $Arguments -notcontains "Microsoft.Component.MSBuild" -or $Arguments -notcontains "-sort"){
        throw "Discovery must include all editions, require MSBuild and prefer newest installations"
    }
    if($Arguments -contains "-all"){throw "Incomplete installations must not be included"}
    return $script:processResult
}
try{
    $installer=Join-Path $fixture "Microsoft Visual Studio\Installer"
    New-Item -ItemType Directory -Path $installer -Force|Out-Null
    New-Item -ItemType File -Path (Join-Path $installer "vswhere.exe")|Out-Null
    $valid=Join-Path $fixture "custom installation\MSBuild.exe"
    New-Item -ItemType Directory -Path (Split-Path -Parent $valid) -Force|Out-Null
    New-Item -ItemType File -Path $valid|Out-Null
    ${env:ProgramFiles(x86)}=$fixture
    $tool=Find-MuxxTool "msbuild"
    $script:processResult=[pscustomobject]@{Success=$true;TimedOut=$false;Output="$(Join-Path $fixture 'missing.exe')`r`n$valid`r`n"}
    $resolved=Resolve-MuxxToolCommand $tool
    if(-not $resolved -or $resolved.Source -ne $valid -or $resolved.OnPath){throw "Registered MSBuild outside PATH was not resolved"}
    $checked=Test-MuxxTool $tool
    if(-not $checked.Installed -or $checked.Status -ne "Warning" -or $checked.Path -ne $valid){throw "Existing MSBuild must not be reported as missing"}

    $script:pathCommand=[pscustomobject]@{Source="preferred-path-MSBuild.exe"}
    $script:calls=0
    $resolved=Resolve-MuxxToolCommand $tool
    if(-not $resolved.OnPath -or $resolved.Source -ne $script:pathCommand.Source -or $script:calls){throw "PATH must retain precedence"}
    $script:pathCommand=$null

    foreach($result in @(
        [pscustomobject]@{Success=$true;TimedOut=$false;Output=""},
        [pscustomobject]@{Success=$true;TimedOut=$false;Output=(Join-Path $fixture "missing.exe")},
        [pscustomobject]@{Success=$false;TimedOut=$false;Output=$valid},
        [pscustomobject]@{Success=$false;TimedOut=$true;Output=""}
    )){
        $script:processResult=$result
        if($null -ne (Resolve-MuxxMSBuild)){throw "Empty, stale, failed or timed-out discovery must not resolve"}
    }
    ${env:ProgramFiles(x86)}=Join-Path $fixture "no installer"
    $script:calls=0
    if($null -ne (Resolve-MuxxMSBuild) -or $script:calls){throw "Missing vswhere must be handled without invoking a process"}
    Write-Host "MSBuild discovery tests passed."
}finally{
    ${env:ProgramFiles(x86)}=$originalProgramFilesX86
    # fixture is the unique absolute directory created above under the temp root.
    if($fixture -and (Split-Path -Parent $fixture).TrimEnd('\') -eq ([IO.Path]::GetTempPath()).TrimEnd('\')){
        Remove-Item -LiteralPath $fixture -Recurse -Force
    }
}
