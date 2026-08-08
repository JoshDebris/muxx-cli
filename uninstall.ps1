#requires -version 5.1
$dir=Join-Path $env:LOCALAPPDATA "MUXX"
$parts=@([Environment]::GetEnvironmentVariable("Path","User") -split ";"|Where-Object{$_ -and $_ -ne $dir})
[Environment]::SetEnvironmentVariable("Path",($parts -join ";"),"User")
Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "✅ MUXX-CLI uninstalled." -ForegroundColor Green
