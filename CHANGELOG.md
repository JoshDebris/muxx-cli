# Changelog

## 1.0.3 - 2026-11-04

- Detect MSBuild installed with Visual Studio or Build Tools via the bundled
  `vswhere.exe`, including Visual Studio 2026 and custom installation paths.
- Preserve PATH precedence and report discovered MSBuild installations outside
  PATH as installed with a warning instead of suggesting a new installation.
- Ignore missing executable paths and failed or timed-out discovery results.
- Add MSBuild discovery regression tests.

### Validation

- Windows PowerShell 5.1 smoke tests and MSBuild discovery tests.
- Live `muxx check msbuild` and `muxx where msbuild` against Build Tools 2026.

### Use the ZIP locally

Extract the archive and run `./muxx.cmd version` or `./muxx.cmd check msbuild`
from the extracted directory. `install.ps1` downloads from GitHub main and
does not install the extracted local files.
