function Test-MuxxWinget { return $null -ne (Get-Command winget.exe -ErrorAction SilentlyContinue|Select-Object -First 1) }
function Get-MuxxInstallReason {
    param([object]$Result)
    if($Result.TimedOut){return "Installation timed out."}
    if($Result.Error){return $Result.Error}
    $line=Get-MuxxFirstLine $Result.Output
    if($line){return $line}
    if($null -ne $Result.ExitCode){return "winget exited with code $($Result.ExitCode)."}
    return "winget did not provide a detailed error."
}
function Install-MuxxWinget {
    param([switch]$AssumeYes)
    Write-Host ""
    Write-Host "MUXX can download the latest official Winget MSIX bundle from GitHub." -ForegroundColor Yellow
    if(-not $AssumeYes -and -not(Read-MuxxYesNo "Install Winget now?")){return $false}
    $tmp=Join-Path $env:TEMP "muxx-winget.msixbundle"
    $previousProgressPreference=$ProgressPreference
    $ProgressPreference="SilentlyContinue"
    try{
        Write-Host "Downloading Winget..." -ForegroundColor Yellow
        $release=Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -UseBasicParsing
        $asset=$release.assets|Where-Object browser_download_url -match '\.msixbundle$'|Select-Object -First 1
        if(-not $asset){throw "No MSIX bundle found."}
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmp -UseBasicParsing
        Write-Host "Installing Winget..." -ForegroundColor Yellow
        Add-AppxPackage -Path $tmp
        return Test-MuxxWinget
    }catch{
        Write-Host "Winget installation failed." -ForegroundColor Red
        Write-Host ""
        Write-Host "Reason:" -ForegroundColor DarkGray
        Write-Host $($_.Exception.Message)
        Write-Host ""
        Write-Host "You can download Winget manually:" -ForegroundColor DarkGray
        Write-Host "https://github.com/microsoft/winget-cli/releases" -ForegroundColor DarkGray
        return $false
    }finally{
        $ProgressPreference=$previousProgressPreference
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}
function Install-MuxxTool {
    param([hashtable]$Tool,[switch]$AssumeYes)
    if(-not $Tool.WingetId){
        Write-Host "Please install $($Tool.Name) manually:" -ForegroundColor DarkGray
        Write-Host $Tool.Website -ForegroundColor DarkGray
        return $false
    }
    if(-not(Test-MuxxWinget)){
        Write-Host "❌ Winget is not available." -ForegroundColor Red
        if(-not(Install-MuxxWinget -AssumeYes:$AssumeYes)){
            Write-Host "Please install $($Tool.Name) manually:" -ForegroundColor DarkGray
            Write-Host $Tool.Website -ForegroundColor DarkGray
            return $false
        }
    }
    $display="winget install --id $($Tool.WingetId) --exact --accept-package-agreements --accept-source-agreements"
    Write-Host "Recommended command:" -ForegroundColor DarkGray
    Write-Host $display -ForegroundColor DarkGray
    if(-not $AssumeYes -and -not(Read-MuxxYesNo "Install $($Tool.Name) now?")){return $false}
    Write-Host "Installing $($Tool.Name)..." -ForegroundColor Yellow
    $r=Invoke-MuxxProcess -FilePath "winget.exe" -Arguments @("install","--id",$Tool.WingetId,"--exact","--accept-package-agreements","--accept-source-agreements") -TimeoutSeconds 900
    if(-not $r.Success){
        Write-Host "Installation failed." -ForegroundColor Red
        Write-Host ""
        Write-Host "Winget could not install $($Tool.Name)."
        Write-Host ""
        Write-Host "Reason:" -ForegroundColor DarkGray
        Write-Host (Get-MuxxInstallReason $r)
        Write-Host ""
        Write-Host "You can download $($Tool.Name) manually:" -ForegroundColor DarkGray
        Write-Host $Tool.Website -ForegroundColor DarkGray
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
