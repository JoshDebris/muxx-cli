#requires -version 5.1
[CmdletBinding()]
param([string]$Repository="JoshDebris/muxx-cli",[string]$Branch="v1.0.0")
$ErrorActionPreference="Stop"
$previousProgressPreference=$ProgressPreference
$ProgressPreference="SilentlyContinue"
$dir=Join-Path $env:LOCALAPPDATA "MUXX"
$base="https://raw.githubusercontent.com/$Repository/$Branch"
$files=@(
    @{Source="muxx.ps1";Target="muxx-core.ps1"},
    @{Source="muxx.cmd";Target="muxx.cmd"},
    @{Source="help.txt";Target="help.txt"},
    @{Source="src/output.ps1";Target="src/output.ps1"},
    @{Source="src/utils.ps1";Target="src/utils.ps1"},
    @{Source="src/registry.ps1";Target="src/registry.ps1"},
    @{Source="src/checker.ps1";Target="src/checker.ps1"},
    @{Source="src/installer.ps1";Target="src/installer.ps1"},
    @{Source="src/commands.ps1";Target="src/commands.ps1"}
)
try{
    Write-Host "Installing MUXX-CLI..." -ForegroundColor Yellow
    foreach($f in $files){
        $target=Join-Path $dir $f.Target
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null
        Invoke-WebRequest -Uri "$base/$($f.Source)" -OutFile $target -UseBasicParsing
    }
    Remove-Item (Join-Path $dir "muxx.ps1") -Force -ErrorAction SilentlyContinue
}finally{
    $ProgressPreference=$previousProgressPreference
}
$userPath=[Environment]::GetEnvironmentVariable("Path","User")
$parts=@($userPath -split ";"|Where-Object{$_})
if($parts -notcontains $dir){
    [Environment]::SetEnvironmentVariable("Path",(($parts+$dir)|Select-Object -Unique)-join ";","User")
}
Write-Host "✅ MUXX-CLI installed." -ForegroundColor Green
Write-Host "Open a new terminal and run: muxx" -ForegroundColor DarkGray
