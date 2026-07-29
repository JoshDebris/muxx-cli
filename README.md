# MUXX-CLI

Fast developer environment checks for Windows.

```powershell
muxx
muxx check php node composer
muxx check --all
muxx doc
muxx where php
```

## Install

```powershell
irm https://raw.githubusercontent.com/JoshDebris/muxx-cli/main/install.ps1 | iex
```

## Design principles

- Runs on every Windows machine.
- No external dependencies.
- No required fonts.
- No PowerShell modules.
- No Internet connection required for normal checks.
- Fast default command.
- Expensive checks are opt-in.
- All CLI output is English.

**MUXX first. Fancy later.**
