# MUXX-CLI

Fast developer environment diagnostics for Windows.

Check your machine. Find missing tools. Install what you need.

MUXX first. Fancy later.

```powershell
muxx
muxx check php node composer
muxx install php
muxx check --all
muxx doc
muxx where php
muxx help
```

## Install

```powershell
irm https://raw.githubusercontent.com/JoshDebris/muxx-cli/v1.0.0/install.ps1 | iex
```

## Design Principles

- Runs on every Windows machine.
- No external dependencies.
- No required fonts.
- No PowerShell modules.
- No Internet connection required for checks.
- Internet only required for optional installations.
- Fast default command.
- Expensive checks are opt-in.
- All CLI output is English.
