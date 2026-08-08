function Get-MuxxToolRegistry {
@(
@{Id="git";Name="Git";Category="Source Control";Command="git";Args=@("--version");Pattern="git version\s+([^\s]+)";WingetId="Git.Git";Website="https://git-scm.com/download/win";Quick=$true},
@{Id="node";Aliases=@("nodejs");Name="Node.js";Category="JavaScript";Command="node";Args=@("--version");Pattern="v?([0-9][^\s]*)";WingetId="OpenJS.NodeJS.LTS";Website="https://nodejs.org/";Quick=$true},
@{Id="npm";Name="npm";Category="JavaScript";Command="npm.cmd";Args=@("--version");Pattern="([0-9][^\s]*)";WingetId="";Website="https://www.npmjs.com/";Quick=$true},
@{Id="python";Aliases=@("py");Name="Python";Category="Python";Command="python";Args=@("--version");Pattern="Python\s+([^\s]+)";WingetId="Python.Python.3.13";Website="https://www.python.org/downloads/windows/";Quick=$true},
@{Id="php";Name="PHP";Category="PHP";Command="php";Args=@("--version");Pattern="PHP\s+([^\s]+)";WingetId="PHP.PHP.8.5";Website="https://windows.php.net/download/";Quick=$true},
@{Id="composer";Name="Composer";Category="PHP";Command="composer";Args=@("--version");Pattern="Composer(?:\s+version)?\s+([^\s]+)";WingetId="Composer.Composer";Website="https://getcomposer.org/download/";Quick=$true},
@{Id="rust";Aliases=@("rustc");Name="Rust";Category="Languages and SDKs";Command="rustc";Args=@("--version");Pattern="rustc\s+([^\s]+)";WingetId="Rustlang.Rustup";Website="https://rustup.rs/";Quick=$false;TimeoutSeconds=8},
@{Id="cargo";Name="Cargo";Category="Languages and SDKs";Command="cargo";Args=@("--version");Pattern="cargo\s+([^\s]+)";WingetId="Rustlang.Rustup";Website="https://rustup.rs/";Quick=$false;TimeoutSeconds=8},
@{Id="go";Name="Go";Category="Languages and SDKs";Command="go";Args=@("version");Pattern="go version go([^\s]+)";WingetId="GoLang.Go";Website="https://go.dev/dl/";Quick=$false},
@{Id="java";Name="Java";Category="Languages and SDKs";Command="java";Args=@("-version");Pattern='version\s+"([^"]+)"';WingetId="EclipseAdoptium.Temurin.21.JDK";Website="https://adoptium.net/";Quick=$false;TimeoutSeconds=8},
@{Id="dotnet";Aliases=@(".net");Name=".NET SDK";Category="Languages and SDKs";Command="dotnet";Args=@("--version");Pattern="([0-9][^\s]*)";WingetId="Microsoft.DotNet.SDK.8";Website="https://dotnet.microsoft.com/download";Quick=$false},
@{Id="docker";Name="Docker";Category="Containers";Command="docker";Args=@("--version");Pattern="Docker version\s+([^,\s]+)";WingetId="Docker.DockerDesktop";Website="https://www.docker.com/products/docker-desktop/";Quick=$false},
@{Id="wsl";Name="WSL";Category="Containers";Command="wsl.exe";Args=@("--version");Pattern="(?:WSL-Version|WSL version):\s*([^\s]+)";WingetId="Microsoft.WSL";Website="https://learn.microsoft.com/windows/wsl/install";Quick=$false},
@{Id="code";Aliases=@("vscode");Name="VS Code";Category="Developer Tools";Command="code.cmd";Args=@("--version");Pattern="^([0-9][^\r\n]*)";WingetId="Microsoft.VisualStudioCode";Website="https://code.visualstudio.com/";Quick=$true},
@{Id="winget";Name="Winget";Category="Developer Tools";Command="winget.exe";Args=@("--version");Pattern="v?([0-9][^\s]*)";WingetId="";Website="https://github.com/microsoft/winget-cli/releases";Quick=$true},
@{Id="curl";Name="Curl";Category="CLI Utilities";Command="curl.exe";Args=@("--version");Pattern="curl\s+([^\s]+)";WingetId="";Website="https://curl.se/windows/";Quick=$true},
@{Id="ffmpeg";Name="FFmpeg";Category="CLI Utilities";Command="ffmpeg";Args=@("-version");Pattern="ffmpeg version\s+([^\s]+)";WingetId="Gyan.FFmpeg";Website="https://ffmpeg.org/download.html";Quick=$false},
@{Id="imagemagick";Aliases=@("magick");Name="ImageMagick";Category="CLI Utilities";Command="magick";Args=@("--version");Pattern="ImageMagick\s+([^\s]+)";WingetId="ImageMagick.ImageMagick";Website="https://imagemagick.org/script/download.php#windows";Quick=$false},
@{Id="jq";Name="jq";Category="CLI Utilities";Command="jq";Args=@("--version");Pattern="jq-([^\s]+)";WingetId="jqlang.jq";Website="https://jqlang.github.io/jq/download/";Quick=$false},
@{Id="ripgrep";Aliases=@("rg");Name="ripgrep";Category="CLI Utilities";Command="rg";Args=@("--version");Pattern="ripgrep\s+([^\s]+)";WingetId="BurntSushi.ripgrep.MSVC";Website="https://github.com/BurntSushi/ripgrep";Quick=$false},
@{Id="fd";Name="fd";Category="CLI Utilities";Command="fd";Args=@("--version");Pattern="fd\s+([^\s]+)";WingetId="sharkdp.fd";Website="https://github.com/sharkdp/fd";Quick=$false},
@{Id="bat";Name="bat";Category="CLI Utilities";Command="bat";Args=@("--version");Pattern="bat\s+([^\s]+)";WingetId="sharkdp.bat";Website="https://github.com/sharkdp/bat";Quick=$false},
@{Id="fzf";Name="fzf";Category="CLI Utilities";Command="fzf";Args=@("--version");Pattern="([0-9][^\s]*)";WingetId="junegunn.fzf";Website="https://github.com/junegunn/fzf";Quick=$false}
)}
function Find-MuxxTool {
    param([string]$Id)
    $needle=$Id.Trim().ToLowerInvariant()
    foreach($t in Get-MuxxToolRegistry){
        if($t.Id -eq $needle){return $t}
        if($t.ContainsKey("Aliases") -and $t.Aliases -contains $needle){return $t}
    }
    return $null
}
