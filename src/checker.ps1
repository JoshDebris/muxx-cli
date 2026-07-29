function Get-MuxxVersion {
    param([string]$Output,[string]$Pattern)
    if($Pattern -and $Output -match $Pattern){return $Matches[1].Trim()}
    return Get-MuxxFirstLine $Output
}
function Test-MuxxTool {
    param([hashtable]$Tool,[switch]$ResolveVersion,[int]$TimeoutSeconds=3)
    $cmd=Get-Command $Tool.Command -ErrorAction SilentlyContinue|Select-Object -First 1
    if(-not $cmd){
        return [pscustomobject]@{Id=$Tool.Id;Name=$Tool.Name;Category=$Tool.Category;Status="NotInstalled";Installed=$false;Version="";Path="";Message="";Tool=$Tool}
    }
    $status="Installed";$version="";$message=""
    if($ResolveVersion){
        $r=Invoke-MuxxProcess -FilePath $cmd.Source -Arguments $Tool.Args -TimeoutSeconds $TimeoutSeconds
        if($r.TimedOut){$status="Warning";$message="Version check timed out"}
        elseif(-not $r.Success -and -not $r.Output){$status="Warning";$message="Version could not be read"}
        else{$version=Get-MuxxVersion $r.Output $Tool.Pattern}
    }
    [pscustomobject]@{Id=$Tool.Id;Name=$Tool.Name;Category=$Tool.Category;Status=$status;Installed=$true;Version=$version;Path=$cmd.Source;Message=$message;Tool=$Tool}
}
function Find-MuxxToolLocations {
    param([hashtable]$Tool)
    $checked=@("PATH")
    $found=@()
    $cmd=Get-Command $Tool.Command -ErrorAction SilentlyContinue|Select-Object -First 1
    if($cmd){$found+=[pscustomobject]@{Source="PATH";Path=$cmd.Source}}

    $checked+="Registry"
    $registryRoots=@(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach($root in $registryRoots){
        Get-ItemProperty $root -ErrorAction SilentlyContinue|ForEach-Object{
            $displayProperty=$_.PSObject.Properties["DisplayName"]
            $displayName=if($displayProperty){$displayProperty.Value}else{""}
            if(-not $displayName -or ($displayName -notlike "*$($Tool.Name)*" -and $displayName -notlike "*$($Tool.Id)*")){return}
            foreach($property in @("InstallLocation","DisplayIcon")){
                $pathProperty=$_.PSObject.Properties[$property]
                $path=if($pathProperty){$pathProperty.Value}else{""}
                if(-not $path){continue}
                $path=($path -replace '^"([^"]+)".*','$1').Trim()
                if(Test-Path -LiteralPath $path){
                    $item=Get-Item -LiteralPath $path -ErrorAction SilentlyContinue
                    if($item -and -not $item.PSIsContainer -and $item.Name -eq $Tool.Command){$found+=[pscustomobject]@{Source="Registry";Path=$item.FullName}}
                    if($item -and $item.PSIsContainer){
                        $candidate=Get-ChildItem -LiteralPath $item.FullName -Filter $Tool.Command -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1
                        if($candidate){$found+=[pscustomobject]@{Source="Registry";Path=$candidate.FullName}}
                    }
                }
            }
        }
    }

    $checked+="Common install locations"
    $commonRoots=@("C:\tools","C:\xampp","C:\laragon","C:\scoop")
    $namedRoots=@($env:ProgramFiles,${env:ProgramFiles(x86)},$env:LOCALAPPDATA)
    $roots=@()
    foreach($root in ($commonRoots|Where-Object{$_ -and (Test-Path -LiteralPath $_)})){
        $roots+=$root
    }
    foreach($root in ($namedRoots|Where-Object{$_ -and (Test-Path -LiteralPath $_)})){
        $roots+=@(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue|Where-Object{
            $_.Name -like "*$($Tool.Name)*" -or $_.Name -like "*$($Tool.Id)*"
        }|Select-Object -ExpandProperty FullName)
    }
    foreach($root in ($roots|Where-Object{$_}|Select-Object -Unique)){
        $candidate=Get-ChildItem -LiteralPath $root -Filter $Tool.Command -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1
        if($candidate){$found+=[pscustomobject]@{Source="Common install locations";Path=$candidate.FullName}}
    }

    [pscustomobject]@{
        Checked=$checked
        Found=@($found|Sort-Object Path -Unique)
    }
}
function Write-MuxxToolResult {
    param([object]$Result)
    $detail=if($Result.Version){$Result.Version}else{$Result.Message}
    Write-MuxxStatus -Status $Result.Status -Name $Result.Name -Detail $detail
    if($Result.Status -eq "NotInstalled"){
        Write-Host ""
        Write-Host "Next:" -ForegroundColor DarkGray
        Write-Host "  muxx install $($Result.Id)"
    }
}
function Invoke-MuxxToolCheck {
    param([hashtable[]]$Tools,[switch]$ResolveVersion,[switch]$ShowProgress,[int]$TimeoutSeconds=3)
    $results=@();$i=0
    foreach($tool in $Tools){
        $i++
        if($ShowProgress){Write-Host ("[{0:D2}/{1:D2}] Checking {2}..." -f $i,$Tools.Count,$tool.Name) -ForegroundColor DarkGray}
        $r=Test-MuxxTool -Tool $tool -ResolveVersion:$ResolveVersion -TimeoutSeconds $TimeoutSeconds
        $results+=$r
        if(-not $ShowProgress){Write-MuxxToolResult $r}
    }
    if($ShowProgress){
        Write-Host ""
        foreach($cat in ($Tools.Category|Select-Object -Unique)){
            Write-MuxxSection $cat
            foreach($r in ($results|Where-Object Category -eq $cat)){Write-MuxxToolResult $r}
            Write-Host ""
        }
    }
    return $results
}
