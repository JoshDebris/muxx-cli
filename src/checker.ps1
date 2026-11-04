function Get-MuxxVersion {
    param([string]$Output,[string]$Pattern)
    $raw = if($Pattern -and $Output -match $Pattern){ $Matches[1] } else { Get-MuxxFirstLine $Output }
    if(-not $raw){ return "" }
    return ($raw -replace '[\x00-\x1F\x7F]', '').Trim()
}
function Resolve-MuxxMSBuild {
    # Visual Studio does not add MSBuild to the global PATH. Ask its installer
    # instead of guessing year/edition paths or trusting stale uninstall entries.
    $programFilesX86=${env:ProgramFiles(x86)}
    if(-not $programFilesX86){return $null}
    $vswhere=Join-Path $programFilesX86 "Microsoft Visual Studio\Installer\vswhere.exe"
    if(-not(Test-Path -LiteralPath $vswhere -PathType Leaf)){return $null}
    $result=Invoke-MuxxProcess -FilePath $vswhere -Arguments @(
        "-products","*","-requires","Microsoft.Component.MSBuild",
        "-sort","-find","MSBuild\**\Bin\MSBuild.exe"
    ) -TimeoutSeconds 3
    if(-not $result.Success -or $result.TimedOut){return $null}
    foreach($line in ($result.Output -split "`r?`n")){
        $candidate=$line.Trim()
        if($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)){
            return [pscustomobject]@{Source=$candidate;OnPath=$false;Discovery="Visual Studio Installer (vswhere)"}
        }
    }
    return $null
}
function Resolve-MuxxToolCommand {
    param([hashtable]$Tool)
    $cmd=Get-Command $Tool.Command -ErrorAction SilentlyContinue|Select-Object -First 1
    if($cmd){return [pscustomobject]@{Source=$cmd.Source;OnPath=$true}}

    if($Tool.Id -eq "msbuild"){
        $msbuild=Resolve-MuxxMSBuild
        if($msbuild){return $msbuild}
    }

    $wingetLinks=Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links"
    $names=@($Tool.Command)
    if(-not [IO.Path]::GetExtension($Tool.Command)){$names+=@("$($Tool.Command).exe","$($Tool.Command).cmd")}
    foreach($name in $names){
        $candidate=Join-Path $wingetLinks $name
        if(Test-Path -LiteralPath $candidate){return [pscustomobject]@{Source=$candidate;OnPath=$false}}
    }

    if($Tool.WingetId){
        $wingetPackages=Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
        $packageDirs=@(Get-ChildItem -LiteralPath $wingetPackages -Directory -Filter "$($Tool.WingetId)_*" -ErrorAction SilentlyContinue)
        $commandBase=[IO.Path]::GetFileNameWithoutExtension($Tool.Command)
        foreach($packageDir in $packageDirs){
            $candidate=Get-ChildItem -LiteralPath $packageDir.FullName -File -Filter "$commandBase*.exe" -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1
            if($candidate){return [pscustomobject]@{Source=$candidate.FullName;OnPath=$false}}
        }
    }
    return $null
}
function Test-MuxxTool {
    param([hashtable]$Tool,[switch]$ResolveVersion,[int]$TimeoutSeconds=3)
    $cmd=Resolve-MuxxToolCommand -Tool $Tool
    if(-not $cmd){
        return [pscustomobject]@{Id=$Tool.Id;Name=$Tool.Name;Category=$Tool.Category;Status="NotInstalled";Installed=$false;Version="";Path="";Message="";Tool=$Tool}
    }
    $status=if($cmd.OnPath){"Installed"}else{"Warning"}
    $version=""
    $message=if($cmd.OnPath){""}else{"Installed, but not on PATH"}
    if($ResolveVersion){
        $effectiveTimeout=if($Tool.ContainsKey("TimeoutSeconds")){$Tool.TimeoutSeconds}else{$TimeoutSeconds}
        $r=Invoke-MuxxProcess -FilePath $cmd.Source -Arguments $Tool.Args -TimeoutSeconds $effectiveTimeout
        if($r.TimedOut){$status="Warning";$message="Version check timed out"}
        elseif(-not $r.Success -and -not $r.Output){$status="Warning";$message="Version could not be read"}
        else{$version=Get-MuxxVersion $r.Output $Tool.Pattern}
    }
    [pscustomobject]@{Id=$Tool.Id;Name=$Tool.Name;Category=$Tool.Category;Status=$status;Installed=$true;Version=$version;Path=$cmd.Source;Message=$message;Tool=$Tool}
}
function Find-MuxxToolLocations {
    param([hashtable]$Tool)
    $checked=@("PATH","Winget links","Winget package directories")
    if($Tool.Id -eq "msbuild"){$checked+="Visual Studio Installer (vswhere)"}
    $found=@()
    $cmd=Resolve-MuxxToolCommand -Tool $Tool
    if($cmd){
        $source=if($cmd.OnPath){"PATH"}elseif($cmd.PSObject.Properties["Discovery"]){$cmd.Discovery}else{"Winget links"}
        $found+=[pscustomobject]@{Source=$source;Path=$cmd.Source}
    }

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
                        $candidate=Get-ChildItem -LiteralPath $item.FullName -Filter $Tool.Command -Recurse -Depth 5 -ErrorAction SilentlyContinue|Select-Object -First 1
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
        $candidate=Get-ChildItem -LiteralPath $root -Filter $Tool.Command -Recurse -Depth 5 -ErrorAction SilentlyContinue|Select-Object -First 1
        if($candidate){$found+=[pscustomobject]@{Source="Common install locations";Path=$candidate.FullName}}
    }

    [pscustomobject]@{
        Checked=$checked
        Found=@($found|Sort-Object Path -Unique)
    }
}
function Write-MuxxToolResult {
    param([object]$Result,[bool]$ShowNext=$true)
    $detail=if($Result.Version -and $Result.Message){"$($Result.Version) | $($Result.Message)"}elseif($Result.Version){$Result.Version}else{$Result.Message}
    Write-MuxxStatus -Status $Result.Status -Name $Result.Name -Detail $detail
    if($ShowNext -and $Result.Status -eq "NotInstalled"){
        Write-Host "Next: muxx install $($Result.Id)" -ForegroundColor DarkGray
        Write-Host ""
    }
}
function Invoke-MuxxToolCheck {
    param([hashtable[]]$Tools,[switch]$ResolveVersion,[switch]$ShowProgress,[bool]$ShowNext=$true,[int]$TimeoutSeconds=3)
    $results=@();$i=0
    foreach($tool in $Tools){
        $i++
        if($ShowProgress){Write-Host ("[{0:D2}/{1:D2}] Checking {2}..." -f $i,$Tools.Count,$tool.Name) -ForegroundColor DarkGray}
        $r=Test-MuxxTool -Tool $tool -ResolveVersion:$ResolveVersion -TimeoutSeconds $TimeoutSeconds
        $results+=$r
        if(-not $ShowProgress){Write-MuxxToolResult -Result $r -ShowNext:$ShowNext}
    }
    if($ShowProgress){
        Write-Host ""
        foreach($cat in ($Tools.Category|Select-Object -Unique)){
            Write-MuxxSection $cat
            foreach($r in ($results|Where-Object Category -eq $cat)){Write-MuxxToolResult -Result $r -ShowNext:$ShowNext}
            Write-Host ""
        }
    }
    return $results
}
