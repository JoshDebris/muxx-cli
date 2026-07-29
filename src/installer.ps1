function Test-MuxxWinget { return $null -ne (Get-Command winget.exe -ErrorAction SilentlyContinue|Select-Object -First 1) }
function Install-MuxxWinget {
    Write-Host ""
    Write-Host "MUXX can download the latest official Winget MSIX bundle from GitHub." -ForegroundColor Yellow
    if(-not(Read-MuxxYesNo "Install Winget now?")){return $false}
    $tmp=Join-Path $env:TEMP "muxx-winget.msixbundle"
    try{
        Write-Host "Downloading Winget..." -ForegroundColor Cyan
        $release=Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -UseBasicParsing
        $asset=$release.assets|Where-Object browser_download_url -match '\.msixbundle$'|Select-Object -First 1
        if(-not $asset){throw "No MSIX bundle found."}
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmp -UseBasicParsing
        Write-Host "Installing Winget..." -ForegroundColor Cyan
        Add-AppxPackage -Path $tmp
        return Test-MuxxWinget
    }catch{
        Write-MuxxError "Winget installation failed: $($_.Exception.Message)"
        Write-Host "https://github.com/microsoft/winget-cli/releases" -ForegroundColor Cyan
        return $false
    }finally{Remove-Item $tmp -Force -ErrorAction SilentlyContinue}
}
function Install-MuxxTool {
    param([hashtable]$Tool)
    if(-not $Tool.WingetId){
        Write-Host "Please install $($Tool.Name) manually:" -ForegroundColor DarkGray
        Write-Host $Tool.Website -ForegroundColor Cyan
        return $false
    }
    if(-not(Test-MuxxWinget)){
        Write-Host "❌ Winget is not available." -ForegroundColor Red
        if(-not(Install-MuxxWinget)){
            Write-Host "Please install $($Tool.Name) manually:" -ForegroundColor DarkGray
            Write-Host $Tool.Website -ForegroundColor Cyan
            return $false
        }
    }
    $display="winget install --id $($Tool.WingetId) --exact --accept-package-agreements --accept-source-agreements"
    Write-Host "Recommended command:" -ForegroundColor DarkGray
    Write-Host $display -ForegroundColor Cyan
    if(-not(Read-MuxxYesNo "Install $($Tool.Name) now?")){return $false}
    Write-Host "Installing $($Tool.Name)..." -ForegroundColor Cyan
    $r=Invoke-MuxxProcess -FilePath "winget.exe" -Arguments @("install","--id",$Tool.WingetId,"--exact","--accept-package-agreements","--accept-source-agreements") -TimeoutSeconds 900
    if(-not $r.Success){
        Write-MuxxError "Installation failed."
        Write-Host $Tool.Website -ForegroundColor Cyan
        return $false
    }
    Write-Host "Verifying installation..." -ForegroundColor DarkGray
    $v=Test-MuxxTool -Tool $Tool -ResolveVersion -TimeoutSeconds 5
    if($v.Installed){Write-MuxxToolResult $v;return $true}
    Write-Host "⚠️  Installed, but not visible in this terminal yet. Open a new terminal." -ForegroundColor Yellow
    return $false
}
function Offer-MuxxInstallations {
    param([object[]]$Results)
    if(-not(Test-MuxxInteractive)){return}
    foreach($r in ($Results|Where-Object Status -eq "NotInstalled")){
        Write-Host ""
        if(Read-MuxxYesNo "Do you want to install $($r.Name) now?"){[void](Install-MuxxTool $r.Tool)}
    }
}
