function Write-MuxxRule {
    param([int]$Length=64,[char]$Character='-')
    Write-Host ($Character.ToString() * $Length) -ForegroundColor DarkGray
}
function Write-MuxxHeader {
    param([string]$Subtitle="Environment Check")
    Write-Host "MUXX-CLI v$script:MuxxVersion" -ForegroundColor Cyan
    Write-Host "================" -ForegroundColor DarkGray
    Write-Host $Subtitle -ForegroundColor DarkGray
    Write-Host ""
}
function Write-MuxxChecking {
    param([string]$Suffix="")
    $text="muxx is checking... 🤓"
    if ($Suffix) { $text += "  $Suffix" }
    Write-Host $text -ForegroundColor DarkGray
    Write-Host ""
}
function Write-MuxxSection {
    param([string]$Title)
    Write-Host $Title.ToUpperInvariant() -ForegroundColor Cyan
    Write-MuxxRule
}
function Write-MuxxStatus {
    param([string]$Status,[string]$Name,[string]$Detail="")
    $label=$Name.PadRight(18)
    switch ($Status) {
        "Installed" {
            Write-Host "✅ " -NoNewline
            Write-Host $label -NoNewline
            Write-Host "Installed" -ForegroundColor Green -NoNewline
        }
        "NotInstalled" {
            Write-Host "❌ " -NoNewline
            Write-Host $label -ForegroundColor DarkGray -NoNewline
            Write-Host "Not installed" -ForegroundColor Red -NoNewline
        }
        default {
            Write-Host "⚠️  " -NoNewline
            Write-Host $label -NoNewline
            Write-Host "Warning" -ForegroundColor Yellow -NoNewline
        }
    }
    if ($Detail) { Write-Host "  $Detail" -ForegroundColor DarkGray } else { Write-Host "" }
}
function Write-MuxxError { param([string]$Message); Write-Host "MUXX error: $Message" -ForegroundColor Red }
function Write-MuxxSummary {
    param([object[]]$Results,[System.Diagnostics.Stopwatch]$Stopwatch)
    $ok=@($Results|Where-Object Status -eq "Installed").Count
    $no=@($Results|Where-Object Status -eq "NotInstalled").Count
    $warn=@($Results|Where-Object Status -eq "Warning").Count
    $score=if($Results.Count){[math]::Round(($ok/$Results.Count)*100)}else{0}
    Write-Host ""
    Write-MuxxSection "Summary"
    Write-Host ("Installed".PadRight(18)) -ForegroundColor DarkGray -NoNewline; Write-Host $ok -ForegroundColor Green
    Write-Host ("Not installed".PadRight(18)) -ForegroundColor DarkGray -NoNewline; Write-Host $no -ForegroundColor Red
    Write-Host ("Warnings".PadRight(18)) -ForegroundColor DarkGray -NoNewline; Write-Host $warn -ForegroundColor Yellow
    Write-Host ("Score".PadRight(18)) -ForegroundColor DarkGray -NoNewline; Write-Host "$score%"
    if($Stopwatch){
        Write-Host ("Environment check completed in {0:N2} seconds." -f $Stopwatch.Elapsed.TotalSeconds) -ForegroundColor DarkGray
    }
}
