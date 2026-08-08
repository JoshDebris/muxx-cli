function Get-MuxxFirstLine {
    param([string]$Text)
    if([string]::IsNullOrWhiteSpace($Text)){return ""}
    return (($Text -split "`r?`n")|Where-Object{$_.Trim()}|Select-Object -First 1).Trim()
}
function ConvertTo-MuxxArguments {
    param([string[]]$Arguments)
    return (($Arguments|ForEach-Object{
        if($_ -match '[\s"]'){ '"' + ($_ -replace '"','\"') + '"' } else { $_ }
    }) -join " ")
}
function Invoke-MuxxProcess {
    param([string]$FilePath,[string[]]$Arguments=@(),[int]$TimeoutSeconds=3)
    $p=New-Object System.Diagnostics.Process
    $p.StartInfo=New-Object System.Diagnostics.ProcessStartInfo
    $p.StartInfo.FileName=$FilePath
    $p.StartInfo.Arguments=ConvertTo-MuxxArguments $Arguments
    $p.StartInfo.UseShellExecute=$false
    $p.StartInfo.RedirectStandardOutput=$true
    $p.StartInfo.RedirectStandardError=$true
    $p.StartInfo.CreateNoWindow=$true
    try{
        [void]$p.Start()
        # Read async BEFORE WaitForExit to prevent pipe-buffer deadlock
        $stdoutTask=$p.StandardOutput.ReadToEndAsync()
        $stderrTask=$p.StandardError.ReadToEndAsync()
        if(-not $p.WaitForExit($TimeoutSeconds*1000)){
            try{$p.Kill()}catch{}
            return [pscustomobject]@{Success=$false;TimedOut=$true;ExitCode=$null;Output="";Error="Timeout"}
        }
        $stdout=$stdoutTask.Result
        $stderr=$stderrTask.Result
        $out=($stdout+"`n"+$stderr).Trim()
        return [pscustomobject]@{Success=($p.ExitCode -eq 0);TimedOut=$false;ExitCode=$p.ExitCode;Output=$out;Error=$stderr.Trim()}
    }catch{
        return [pscustomobject]@{Success=$false;TimedOut=$false;ExitCode=$null;Output="";Error=$_.Exception.Message}
    }finally{$p.Dispose()}
}
function Invoke-MuxxInteractiveProcess {
    param([string]$FilePath,[string[]]$Arguments=@())
    try{
        & $FilePath @Arguments|ForEach-Object{Write-Host $_}
        $exitCode=$LASTEXITCODE
        Write-Output -NoEnumerate ([pscustomobject]@{Success=($exitCode -eq 0);ExitCode=$exitCode;Error=""})
    }catch{
        Write-Output -NoEnumerate ([pscustomobject]@{Success=$false;ExitCode=$null;Error=$_.Exception.Message})
    }
}
function Test-MuxxInteractive {
    try { return [Environment]::UserInteractive -and -not [Console]::IsInputRedirected } catch { return $false }
}
function Read-MuxxYesNo {
    param([string]$Prompt,[bool]$DefaultYes=$true)
    if(-not(Test-MuxxInteractive)){return $false}
    $suffix=if($DefaultYes){"[Y/n]"}else{"[y/N]"}
    $a=Read-Host "$Prompt $suffix"
    if([string]::IsNullOrWhiteSpace($a)){return $DefaultYes}
    return $a.Trim().ToLowerInvariant() -in @("y","yes")
}
function Get-MuxxSystemSummary {
    $os=Get-CimInstance Win32_OperatingSystem
    $cpu=Get-CimInstance Win32_Processor|Select-Object -First 1
    $cs=Get-CimInstance Win32_ComputerSystem
    $up=(Get-Date)-$os.LastBootUpTime
    [pscustomobject]@{
        Windows="$($os.Caption) | Build $($os.BuildNumber)"
        CPU=$cpu.Name.Trim()
        Memory="$([math]::Round($cs.TotalPhysicalMemory/1GB,1)) GB total | $([math]::Round($os.FreePhysicalMemory/1MB,1)) GB free"
        Uptime="{0}d {1}h {2}m" -f $up.Days,$up.Hours,$up.Minutes
        Host=$env:COMPUTERNAME
        User=$env:USERNAME
        PowerShell=$PSVersionTable.PSVersion.ToString()
    }
}
