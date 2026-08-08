# ---------------------------------------------------------------------------
# Doctor result accumulators  (reset by Invoke-MuxxDoctor each run)
# ---------------------------------------------------------------------------
$script:_DocPassed   = 0
$script:_DocWarnings = 0
$script:_DocProblems = 0
$script:_DocFixes    = [System.Collections.Generic.List[string]]::new()

# Unicode symbols computed at runtime to avoid source-file encoding issues
$script:_DocSymPass  = [char]0x2713   # checkmark
$script:_DocSymFail  = [char]0x2717   # ballot x

function Add-DoctorPass {
    param([string]$Text)
    Write-Host "  $($script:_DocSymPass) " -ForegroundColor Green -NoNewline
    Write-Host $Text
    $script:_DocPassed++
}

function Add-DoctorWarn {
    param([string]$Text, [string]$Fix = "")
    Write-Host "  ! " -ForegroundColor Yellow -NoNewline
    Write-Host $Text
    $script:_DocWarnings++
    if ($Fix) { [void]$script:_DocFixes.Add($Fix) }
}

function Add-DoctorFail {
    param([string]$Text, [string]$Fix = "")
    Write-Host "  $($script:_DocSymFail) " -ForegroundColor Red -NoNewline
    Write-Host $Text
    $script:_DocProblems++
    if ($Fix) { [void]$script:_DocFixes.Add($Fix) }
}

function Write-DoctorSection {
    param([string]$Title)
    Write-Host ""
    Write-Host $Title.ToUpperInvariant() -ForegroundColor Cyan
    Write-MuxxRule
}

# ---------------------------------------------------------------------------
# Sections
# ---------------------------------------------------------------------------

function Invoke-DoctorPathSection {
    Write-DoctorSection "PATH"

    $muxxDir   = $script:MuxxRoot
    $pathParts = @($env:Path -split ";" | Where-Object { $_ })

    # MUXX in PATH
    if ($pathParts -contains $muxxDir) {
        Add-DoctorPass "MUXX directory found in PATH"
    } else {
        Add-DoctorFail "MUXX directory not in PATH"
    }

    # Show only tools that are actually on PATH
    foreach ($toolId in @("git", "php", "node", "python", "docker")) {
        $cmd = Get-Command "$toolId.exe" -ErrorAction SilentlyContinue
        if (-not $cmd) { $cmd = Get-Command $toolId -ErrorAction SilentlyContinue }
        if ($cmd) { Add-DoctorPass "$toolId executable resolved" }
    }

    # Duplicate PATH entries
    $uniqueCount = (@($pathParts | Select-Object -Unique)).Count
    $dupCount    = $pathParts.Count - $uniqueCount
    if ($dupCount -gt 0) {
        Add-DoctorWarn "$dupCount duplicate PATH $(if($dupCount -eq 1){'entry'}else{'entries'}) found"
    } else {
        Add-DoctorPass "No duplicate PATH entries"
    }
}

function Invoke-DoctorPhpSection {
    Write-DoctorSection "PHP"

    $phpCmd = Get-Command "php.exe" -ErrorAction SilentlyContinue
    if (-not $phpCmd) { $phpCmd = Get-Command "php" -ErrorAction SilentlyContinue }

    if ($phpCmd) {
        Add-DoctorPass "PHP is executable"

        # Composer
        $composerCmd = Get-Command "composer" -ErrorAction SilentlyContinue
        if ($composerCmd) {
            Add-DoctorPass "Composer is available"
        } else {
            Add-DoctorFail "Composer not found" "muxx install composer"
        }

        # PHP dir in current session PATH
        $phpDir    = Split-Path -Parent $phpCmd.Source
        $pathParts = @($env:Path -split ";" | Where-Object { $_ })
        if ($pathParts -contains $phpDir) {
            Add-DoctorPass "PHP directory is in current session PATH"
        } else {
            Add-DoctorWarn "PHP directory not visible in current session PATH"
        }
    } else {
        Add-DoctorFail "PHP not found" "muxx install php"
    }
}

function Invoke-DoctorNodeSection {
    Write-DoctorSection "NODE.JS"

    $nodeCmd = Get-Command "node.exe" -ErrorAction SilentlyContinue
    if (-not $nodeCmd) { $nodeCmd = Get-Command "node" -ErrorAction SilentlyContinue }

    if ($nodeCmd) {
        Add-DoctorPass "Node.js is executable"

        $npmCmd = Get-Command "npm.cmd" -ErrorAction SilentlyContinue
        if (-not $npmCmd) { $npmCmd = Get-Command "npm" -ErrorAction SilentlyContinue }

        if ($npmCmd) {
            Add-DoctorPass "npm is executable"

            # npm should live in the same directory as node
            $nodeDir = Split-Path -Parent $nodeCmd.Source
            $npmDir  = Split-Path -Parent $npmCmd.Source
            if ($nodeDir -eq $npmDir) {
                Add-DoctorPass "npm belongs to current Node.js installation"
            } else {
                Add-DoctorWarn "npm path differs from node path (may indicate multiple Node installs)"
            }
        } else {
            Add-DoctorFail "npm not found" "Reinstall Node.js from nodejs.org"
        }
    } else {
        Add-DoctorFail "Node.js not found" "muxx install node"
    }
}

function Invoke-DoctorDockerSection {
    Write-DoctorSection "DOCKER"

    $dockerCmd = Get-Command "docker.exe" -ErrorAction SilentlyContinue
    if (-not $dockerCmd) { $dockerCmd = Get-Command "docker" -ErrorAction SilentlyContinue }

    if ($dockerCmd) {
        Add-DoctorPass "Docker is available"
    } else {
        Add-DoctorFail "Docker not found" "muxx install docker"
    }

    # WSL
    $wslCmd = Get-Command "wsl.exe" -ErrorAction SilentlyContinue
    if ($wslCmd) {
        Add-DoctorPass "WSL installed"
        if (-not $dockerCmd) {
            Add-DoctorWarn "Docker can be installed, prerequisites look good"
        }
    } else {
        Add-DoctorWarn "WSL not found (recommended for Docker on Windows)"
    }
}

function Invoke-DoctorGitSection {
    Write-DoctorSection "GIT"

    $gitCmd = Get-Command "git.exe" -ErrorAction SilentlyContinue
    if (-not $gitCmd) { $gitCmd = Get-Command "git" -ErrorAction SilentlyContinue }

    if ($gitCmd) {
        Add-DoctorPass "Git is executable"

        # user.name
        try {
            $name = (& git config --global user.name 2>$null)
            if ($name) {
                Add-DoctorPass "User name configured ($name)"
            } else {
                Add-DoctorFail "User name not configured" 'git config --global user.name "Your Name"'
            }
        } catch {
            Add-DoctorWarn "Could not read git user.name"
        }

        # user.email
        try {
            $email = (& git config --global user.email 2>$null)
            if ($email) {
                Add-DoctorPass "User email configured ($email)"
            } else {
                Add-DoctorFail "User email not configured" 'git config --global user.email "you@example.com"'
            }
        } catch {
            Add-DoctorWarn "Could not read git user.email"
        }
    } else {
        Add-DoctorFail "Git not found" "muxx install git"
    }
}

function Invoke-DoctorPowerShellSection {
    Write-DoctorSection "POWERSHELL"

    $ver = $PSVersionTable.PSVersion
    if ($ver.Major -ge 7) {
        Add-DoctorPass "PowerShell $($ver.ToString()) detected"
    } else {
        Add-DoctorPass "Windows PowerShell $($ver.ToString()) detected"
    }

    # Execution policy
    try {
        $policy     = Get-ExecutionPolicy
        $restricted = @("Restricted", "AllSigned")
        if ($restricted -contains $policy) {
            Add-DoctorFail "Execution policy is $policy - MUXX scripts may be blocked" "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"
        } else {
            Add-DoctorPass "Execution policy allows MUXX ($policy)"
        }
    } catch {
        Add-DoctorWarn "Could not read execution policy"
    }

    # UTF-8 / Unicode console output check
    $isPSCore = $ver.Major -ge 6
    $enc      = [Console]::OutputEncoding
    $isUtf8   = ($enc.CodePage -eq 65001) -or ($OutputEncoding.CodePage -eq 65001) -or $isPSCore -or $env:WT_SESSION -or $env:CMDER_ROOT

    if ($isUtf8) {
        Add-DoctorPass "UTF-8 / Unicode console output available"
    } else {
        Add-DoctorWarn "Console encoding is $($enc.EncodingName) (CodePage $($enc.CodePage)) — external tool output may require UTF-8"
    }
}

function Invoke-DoctorMuxxSection {
    Write-DoctorSection "MUXX"

    $dir = $script:MuxxRoot

    if (-not (Test-Path $dir)) {
        Add-DoctorFail "Installation directory not found ($dir)"
        return
    }
    Add-DoctorPass "Installation directory found"

    # Source files
    $sourceFiles = @(
        "muxx.ps1", "muxx.cmd", "help.txt",
        "src\output.ps1", "src\utils.ps1", "src\registry.ps1",
        "src\checker.ps1", "src\installer.ps1", "src\updater.ps1",
        "src\doc.ps1", "src\doctor.ps1", "src\commands.ps1"
    )
    $missing = @($sourceFiles | Where-Object { -not (Test-Path (Join-Path $dir $_)) })
    if ($missing.Count -eq 0) {
        Add-DoctorPass "All source files present"
    } else {
        Add-DoctorFail "$($missing.Count) source file(s) missing" "muxx update"
    }

    # MUXX in PATH
    $pathParts = @($env:Path -split ";" | Where-Object { $_ })
    if ($pathParts -contains $dir) {
        Add-DoctorPass "MUXX available in PATH"
    } else {
        Add-DoctorFail "MUXX not in PATH"
    }

    # GitHub API reachable
    try {
        $headers = @{ "User-Agent" = "muxx-cli/$($script:MuxxVersion)" }
        $null = Invoke-RestMethod -Uri "https://api.github.com/repos/JoshDebris/muxx-cli/releases/latest" -Headers $headers -UseBasicParsing -ErrorAction Stop
        Add-DoctorPass "Update check reachable"
    } catch {
        Add-DoctorWarn "Update check not reachable (GitHub API)"
    }
}

# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

function Invoke-MuxxDoctor {
    $sw = [Diagnostics.Stopwatch]::StartNew()

    # Reset all accumulators
    $script:_DocPassed   = 0
    $script:_DocWarnings = 0
    $script:_DocProblems = 0
    $script:_DocFixes    = [System.Collections.Generic.List[string]]::new()

    Write-MuxxHeader "Environment Doctor"
    $stethoscope = [char]::ConvertFromUtf32(0x1FA7A)
    Write-Host "muxx is examining your setup... $stethoscope" -ForegroundColor DarkGray

    Invoke-DoctorPathSection
    Invoke-DoctorPhpSection
    Invoke-DoctorNodeSection
    Invoke-DoctorDockerSection
    Invoke-DoctorGitSection
    Invoke-DoctorPowerShellSection
    Invoke-DoctorMuxxSection

    # Diagnosis summary
    $sw.Stop()
    Write-DoctorSection "DIAGNOSIS"
    Write-Host ("Passed".PadRight(20))   -ForegroundColor DarkGray -NoNewline; Write-Host $script:_DocPassed   -ForegroundColor Green
    Write-Host ("Warnings".PadRight(20)) -ForegroundColor DarkGray -NoNewline; Write-Host $script:_DocWarnings -ForegroundColor Yellow
    Write-Host ("Problems".PadRight(20)) -ForegroundColor DarkGray -NoNewline
    if ($script:_DocProblems -gt 0) {
        Write-Host $script:_DocProblems -ForegroundColor Red
    } else {
        Write-Host $script:_DocProblems
    }

    if ($script:_DocFixes.Count -gt 0) {
        Write-Host ""
        Write-Host "Recommended fixes:" -ForegroundColor DarkGray
        Write-Host ""
        foreach ($fix in $script:_DocFixes) {
            Write-Host "  $fix" -ForegroundColor Cyan
        }
    }

    Write-Host ""
    Write-Host ("Doctor completed in {0:N2} seconds." -f $sw.Elapsed.TotalSeconds) -ForegroundColor DarkGray
}
