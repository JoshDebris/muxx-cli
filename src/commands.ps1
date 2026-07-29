function Show-MuxxSystem {
    $s=Get-MuxxSystemSummary
    Write-MuxxSection "System"
    foreach($row in @(
        @("Windows",$s.Windows),@("CPU",$s.CPU),@("Memory",$s.Memory),
        @("Uptime",$s.Uptime),@("Host",$s.Host),@("User",$s.User),@("PowerShell",$s.PowerShell)
    )){
        Write-Host ($row[0].PadRight(18)) -ForegroundColor DarkGray -NoNewline
        Write-Host $row[1]
    }
    Write-Host ""
}
function Show-MuxxHelp {
    $f=Join-Path $script:MuxxRoot "help.txt"
    if(Test-Path $f){Get-Content $f|ForEach-Object{Write-Host $_}}else{Write-MuxxError "help.txt is missing."}
}
function Invoke-MuxxInstallCommand {
    param([string[]]$Arguments)
    $ids=@($Arguments|Where-Object{$_ -and -not $_.StartsWith("-")})
    if(-not $ids.Count){throw "No tool specified. Example: muxx install php"}
    $completed=$true
    foreach($id in $ids){
        $tool=Find-MuxxTool $id
        if(-not $tool){
            Write-Host "⚠️  Unknown tool: $id" -ForegroundColor Yellow
            $completed=$false
            continue
        }
        $current=Test-MuxxTool -Tool $tool -ResolveVersion -TimeoutSeconds 3
        if($current.Installed){
            Write-MuxxToolResult $current
            continue
        }
        if(-not(Install-MuxxTool -Tool $tool -AssumeYes)){
            $completed=$false
        }
    }
    if(-not $completed){throw "Installation was not completed."}
}
function Invoke-MuxxQuickCheck {
    $sw=[Diagnostics.Stopwatch]::StartNew()
    Write-MuxxHeader;Write-MuxxChecking;Show-MuxxSystem
    Write-MuxxSection "Core Tools"
    $tools=@(Get-MuxxToolRegistry|Where-Object Quick)
    $results=Invoke-MuxxToolCheck -Tools $tools -ResolveVersion -TimeoutSeconds 2
    $sw.Stop();Write-MuxxSummary $results $sw
}
function Invoke-MuxxCheckCommand {
    param([string[]]$Arguments)
    $sw=[Diagnostics.Stopwatch]::StartNew()
    $all=$Arguments -contains "--all"
    Write-MuxxHeader $(if($all){"Full Environment Check"}else{"Environment Check"})
    Write-MuxxChecking $(if($all){"everything"}else{""})
    if($all){
        Show-MuxxSystem
        $tools=@(Get-MuxxToolRegistry)
        $results=Invoke-MuxxToolCheck -Tools $tools -ResolveVersion -ShowProgress -TimeoutSeconds 4
    }else{
        $ids=@($Arguments|Where-Object{$_ -and -not $_.StartsWith("-")})
        if(-not $ids.Count){throw "No tools specified. Example: muxx check php node composer"}
        $tools=@()
        foreach($id in $ids){
            $t=Find-MuxxTool $id
            if($t){$tools+=$t}else{Write-Host "⚠️  Unknown tool: $id" -ForegroundColor Yellow}
        }
        if(-not $tools.Count){throw "No known tools were selected."}
        $results=Invoke-MuxxToolCheck -Tools $tools -ResolveVersion -TimeoutSeconds 3
        Offer-MuxxInstallations $results
    }
    $sw.Stop();Write-MuxxSummary $results $sw
}
function Invoke-MuxxWhereCommand {
    param([string[]]$Arguments)
    $id=$Arguments|Where-Object{$_ -and -not $_.StartsWith("-")}|Select-Object -First 1
    if(-not $id){throw "No tool specified. Example: muxx where php"}
    $tool=Find-MuxxTool $id
    if(-not $tool){throw "Unknown tool: $id"}
    Write-MuxxHeader "Tool Location"
    $r=Test-MuxxTool -Tool $tool -ResolveVersion
    if($r.Installed){
        Write-MuxxToolResult $r
        Write-Host "";Write-MuxxSection "Location"
        Write-Host ("Executable".PadRight(18)) -ForegroundColor DarkGray -NoNewline;Write-Host $r.Path
        Write-Host ("PATH entry".PadRight(18)) -ForegroundColor DarkGray -NoNewline;Write-Host (Split-Path -Parent $r.Path)
    }else{
        $locations=Find-MuxxToolLocations -Tool $tool
        Write-Host $tool.Name
        Write-Host ""
        if($locations.Found.Count){
            Write-Host "⚠️  Found outside PATH" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Locations:" -ForegroundColor DarkGray
            foreach($found in $locations.Found){
                Write-Host "- $($found.Path)"
            }
            Write-Host ""
            Write-Host "Next:" -ForegroundColor DarkGray
            Write-Host "  Add the directory to PATH, then open a new terminal."
        }else{
            Write-Host "❌ Not installed" -ForegroundColor Red
            Write-Host ""
            Write-Host "Search paths checked:" -ForegroundColor DarkGray
            foreach($source in $locations.Checked){
                Write-Host "- $source"
            }
            Write-Host ""
            Write-Host "Install:" -ForegroundColor DarkGray
            Write-Host "  muxx install $($tool.Id)"
        }
    }
}
function Invoke-MuxxCommand {
    param([string]$Command,[string[]]$Arguments)
    $c=if($Command){$Command.ToLowerInvariant()}else{""}
    switch($c){
        ""{Invoke-MuxxQuickCheck}
        "check"{Invoke-MuxxCheckCommand $Arguments}
        "install"{Invoke-MuxxInstallCommand $Arguments}
        "doc"{Invoke-MuxxCheckCommand (@("--all")+$Arguments)}
        "where"{Invoke-MuxxWhereCommand $Arguments}
        "help"{Show-MuxxHelp}
        "--help"{Show-MuxxHelp}
        "-h"{Show-MuxxHelp}
        "version"{Write-Host "MUXX-CLI v$script:MuxxVersion"}
        "--version"{Write-Host "MUXX-CLI v$script:MuxxVersion"}
        "-v"{Write-Host "MUXX-CLI v$script:MuxxVersion"}
        default{throw "Unknown command: $Command. Run 'muxx help'."}
    }
}
