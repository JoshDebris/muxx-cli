#requires -version 5.1
[CmdletBinding()]
param(
    [Parameter(Position=0)][string]$Command,
    [Parameter(Position=1, ValueFromRemainingArguments=$true)][string[]]$CommandArgs
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$script:MuxxRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:MuxxVersion = "1.0.0"

@("output","utils","registry","checker","installer","updater","commands") | ForEach-Object {
    $file = Join-Path $script:MuxxRoot "src\$_.ps1"
    if (-not (Test-Path -LiteralPath $file)) { throw "Required MUXX file is missing: $file" }
    . $file
}

try { Invoke-MuxxCommand -Command $Command -Arguments $CommandArgs }
catch { Write-MuxxError $_.Exception.Message; exit 1 }
