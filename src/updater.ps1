function Get-MuxxLatestVersion {
    try {
        $headers = @{ "User-Agent" = "muxx-cli/$script:MuxxVersion" }
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/JoshDebris/muxx-cli/releases/latest" -Headers $headers -UseBasicParsing -ErrorAction Stop
        return $release.tag_name -replace '^v', ''
    } catch {
        throw "Could not fetch latest version from GitHub: $($_.Exception.Message)"
    }
}

function Invoke-MuxxUpdate {
    $repository = "JoshDebris/muxx-cli"
    $branch     = "main"
    $dir        = $script:MuxxRoot
    $current    = $script:MuxxVersion

    $files = @(
        "muxx.ps1",
        "muxx.cmd",
        "help.txt",
        "src/output.ps1",
        "src/utils.ps1",
        "src/registry.ps1",
        "src/checker.ps1",
        "src/installer.ps1",
        "src/updater.ps1",
        "src/commands.ps1"
    )

    Write-Host ""
    Write-Host ("Current version".PadRight(20)) -ForegroundColor DarkGray -NoNewline
    Write-Host "v$current"

    Write-Host ("Checking GitHub...".PadRight(20)) -ForegroundColor DarkGray -NoNewline
    $latest = Get-MuxxLatestVersion
    Write-Host "v$latest"
    Write-Host ""

    if ($current -eq $latest) {
        Write-Host "✅ Already up to date." -ForegroundColor Green
        return
    }

    Write-Host "Updating MUXX..." -ForegroundColor Yellow
    Write-Host ""

    $base         = "https://raw.githubusercontent.com/$repository/refs/tags/v$latest"
    $cacheBust    = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $prevProgress = $ProgressPreference
    $ProgressPreference = "SilentlyContinue"

    try {
        foreach ($f in $files) {
            $target = Join-Path $dir ($f -replace '/', '\')
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            Invoke-WebRequest -Uri "$base/$($f)?cb=$cacheBust" -OutFile $target -UseBasicParsing -ErrorAction Stop
        }
    } catch {
        throw "Update failed while downloading files: $($_.Exception.Message)"
    } finally {
        $ProgressPreference = $prevProgress
    }

    Write-Host "✅ Files updated" -ForegroundColor Green
    Write-Host ""
    Write-Host "MUXX-CLI updated to v$latest" -ForegroundColor Cyan
    Write-Host "Open a new terminal to use the updated version." -ForegroundColor DarkGray
}
