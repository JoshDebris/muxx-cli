$dir=Join-Path $env:LOCALAPPDATA "MUXX"
$parts=@([Environment]::GetEnvironmentVariable("Path","User") -split ";"|Where-Object{$_ -and $_ -ne $dir})
[Environment]::SetEnvironmentVariable("Path",($parts -join ";"),"User")
Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
$pass=[char]0x2713
Write-Host "$pass MUXX-CLI uninstalled." -ForegroundColor Green
