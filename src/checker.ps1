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
function Write-MuxxToolResult {
    param([object]$Result)
    $detail=if($Result.Version){$Result.Version}else{$Result.Message}
    Write-MuxxStatus -Status $Result.Status -Name $Result.Name -Detail $detail
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
