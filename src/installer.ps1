function Test-MuxxWinget { return $null -ne (Get-Command winget.exe -ErrorAction SilentlyContinue|Select-Object -First 1) }
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
        switch($Tool.Id){
            "npm" {
                Write-Host "npm is bundled with Node.js." -ForegroundColor DarkGray
                Write-Host "Install Node.js instead:  muxx install node" -ForegroundColor DarkGray
            }
            "curl" {
                Write-Host "curl is built into Windows 10 and newer." -ForegroundColor DarkGray
                Write-Host "If it is missing, update Windows or download from:" -ForegroundColor DarkGray
                Write-Host $Tool.Website -ForegroundColor DarkGray
            }
            "composer" {
                Write-Host "Composer is not available via Winget." -ForegroundColor Yellow
                Write-Host "MUXX can download the official Composer-Setup.exe from getcomposer.org." -ForegroundColor Yellow
                if(-not $AssumeYes -and -not(Read-MuxxYesNo "Install Composer now?")){return $false}
                $setup=Join-Path $env:TEMP "Composer-Setup.exe"
                try{
                    Write-Host "Downloading Composer-Setup.exe..." -ForegroundColor Yellow
                    Invoke-WebRequest -Uri "https://getcomposer.org/Composer-Setup.exe" -OutFile $setup -UseBasicParsing
                    Write-Host "Running Composer-Setup.exe..." -ForegroundColor Yellow
                    $proc = Start-Process -FilePath $setup -Wait -PassThru
                    return ($proc.ExitCode -eq 0)
                }catch{
                    Write-Host "Composer installation failed: $($_.Exception.Message)" -ForegroundColor Red
                    Write-Host "Please download manually: https://getcomposer.org/download/" -ForegroundColor DarkGray
                    return $false
                }finally{
                    Remove-Item $setup -Force -ErrorAction SilentlyContinue
                }
            }
            default {
                Write-Host "Please install $($Tool.Name) manually:" -ForegroundColor DarkGray
                Write-Host $Tool.Website -ForegroundColor DarkGray
            }
        }
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
    $wingetId=$Tool.WingetId
    if($Tool.ContainsKey("WingetVersions") -and $Tool.WingetVersions.Count -gt 0){
        $chosen=Read-MuxxVersionChoice -ToolName $Tool.Name -Versions $Tool.WingetVersions
        $wingetId=$chosen.WingetId
    }
    $wingetArgs=@("install","--id",$wingetId,"--exact","--source","winget","--accept-package-agreements","--accept-source-agreements")
    $display="winget $((ConvertTo-MuxxArguments $wingetArgs))"
    Write-Host "Recommended command:" -ForegroundColor DarkGray
    Write-Host $display -ForegroundColor DarkGray
    if(-not $AssumeYes -and -not(Read-MuxxYesNo "Install $($Tool.Name) now?")){return $false}
    Write-Host "Installing $($Tool.Name)..." -ForegroundColor Yellow
    $r=Invoke-MuxxInteractiveProcess -FilePath "winget.exe" -Arguments $wingetArgs
    if(-not $r.Success){
        Write-Host "Retrying Winget search..." -ForegroundColor DarkGray
        $fallbackArgs=@("install","--id",$wingetId,"--accept-package-agreements","--accept-source-agreements")
        $r=Invoke-MuxxInteractiveProcess -FilePath "winget.exe" -Arguments $fallbackArgs
    }
    if(-not $r.Success){
        Write-Host "Installation failed." -ForegroundColor Red
        Write-Host ""
        Write-Host "$($Tool.Name) installation via Winget did not complete."
        if($null -ne $r.ExitCode){Write-Host "Winget exited with code $($r.ExitCode)." -ForegroundColor DarkGray}
        if($r.Error){Write-Host $r.Error -ForegroundColor DarkGray}
        Write-Host ""
        Write-Host "Recommended:" -ForegroundColor DarkGray
        Write-Host "Download $($Tool.Name) manually from the official website:"
        Write-Host $Tool.Website -ForegroundColor DarkGray
        return $false
    }
    Write-Host "Verifying installation..." -ForegroundColor DarkGray
    $v=Test-MuxxTool -Tool $Tool -ResolveVersion -TimeoutSeconds 5
    if($v.Installed){Write-MuxxToolResult $v;return $true}
    Write-Host "Installed, but not visible in this terminal yet. Open a new terminal." -ForegroundColor Yellow
    return $false
}
function Invoke-MuxxInstallOffer {
    param([object[]]$Results)
    if(-not(Test-MuxxInteractive)){return}
    foreach($r in ($Results|Where-Object Status -eq "NotInstalled")){
        Write-Host ""
        if(Read-MuxxYesNo "Do you want to install $($r.Name) now?"){[void](Install-MuxxTool -Tool $r.Tool -AssumeYes)}
    }
}
