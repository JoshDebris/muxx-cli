#requires -version 5.1
[CmdletBinding()]
param([string]$Repository="JoshDebris/muxx-cli",[string]$Branch="main")
$ErrorActionPreference="Stop"
$dir=Join-Path $env:LOCALAPPDATA "MUXX"
$base="https://raw.githubusercontent.com/$Repository/$Branch"
$files=@("muxx.ps1","muxx.cmd","help.txt","src/output.ps1","src/utils.ps1","src/registry.ps1","src/checker.ps1","src/installer.ps1","src/commands.ps1")
Write-Host "Installing MUXX-CLI..." -ForegroundColor Cyan
foreach($f in $files){
    $target=Join-Path $dir $f
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null
    Invoke-WebRequest -Uri "$base/$f" -OutFile $target -UseBasicParsing
}
$userPath=[Environment]::GetEnvironmentVariable("Path","User")
$parts=@($userPath -split ";"|Where-Object{$_})
if($parts -notcontains $dir){
    [Environment]::SetEnvironmentVariable("Path",(($parts+$dir)|Select-Object -Unique)-join ";","User")
}
Write-Host "✅ MUXX-CLI installed." -ForegroundColor Green
Write-Host "Open a new terminal and run: muxx" -ForegroundColor DarkGray
