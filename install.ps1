$ErrorActionPreference="Stop"
$Repository="JoshDebris/muxx-cli"
$Branch="main"
$previousProgressPreference=$ProgressPreference
$ProgressPreference="SilentlyContinue"
$dir=Join-Path $env:LOCALAPPDATA "MUXX"
$base="https://raw.githubusercontent.com/$Repository/$Branch"
$cacheBust=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$files=@(
    @{Source="muxx.ps1";Target="muxx.ps1"},
    @{Source="muxx.cmd";Target="muxx.cmd"},
    @{Source="help.txt";Target="help.txt"},
    @{Source="src/output.ps1";Target="src/output.ps1"},
    @{Source="src/utils.ps1";Target="src/utils.ps1"},
    @{Source="src/registry.ps1";Target="src/registry.ps1"},
    @{Source="src/checker.ps1";Target="src/checker.ps1"},
    @{Source="src/installer.ps1";Target="src/installer.ps1"},
    @{Source="src/updater.ps1";Target="src/updater.ps1"},
    @{Source="src/doc.ps1";Target="src/doc.ps1"},
    @{Source="src/doctor.ps1";Target="src/doctor.ps1"},
    @{Source="src/commands.ps1";Target="src/commands.ps1"}
)
try{
    Write-Host "Installing MUXX-CLI..." -ForegroundColor Yellow
    foreach($f in $files){
        $target=Join-Path $dir $f.Target
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null
        Invoke-WebRequest -Uri "$base/$($f.Source)?cb=$cacheBust" -OutFile $target -UseBasicParsing
    }
}finally{
    $ProgressPreference=$previousProgressPreference
}
$userPath=[Environment]::GetEnvironmentVariable("Path","User")
$parts=@($userPath -split ";"|Where-Object{$_})
if($parts -notcontains $dir){
    [Environment]::SetEnvironmentVariable("Path",(($parts+$dir)|Select-Object -Unique)-join ";","User")
}
$sessionParts=@($env:Path -split ";"|Where-Object{$_})
if($sessionParts -notcontains $dir){
    $env:Path=(($sessionParts+$dir)|Select-Object -Unique)-join ";"
}
Write-Host "✅ MUXX-CLI installed." -ForegroundColor Green
Write-Host "Run: muxx" -ForegroundColor DarkGray
