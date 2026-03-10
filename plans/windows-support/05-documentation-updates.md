# Phase 5 - Documentation updates

## Goal

Update the docs so Windows support is described as a first-class path once the implementation phases land.

## Files to update later

- `/home/runner/work/rtk-g/rtk-g/README.md`
- `/home/runner/work/rtk-g/rtk-g/INSTALL.md`
- `/home/runner/work/rtk-g/rtk-g/ARCHITECTURE.md`
- optionally `/home/runner/work/rtk-g/rtk-g/CLAUDE.md` if contributor guidance still says Windows must use `--claude-md`

## Current doc gaps

- README quick install is Linux/macOS only
- Windows is still described mainly as a binary download path
- quick-start text assumes Unix-style hook registration
- architecture claims are ahead of current Windows hook/init reality

## Recommended README snippet

````md
### Quick Install (Windows PowerShell)

```powershell
irm https://raw.githubusercontent.com/Ton-Git/rtk-g/refs/heads/develop/install.ps1 | iex
```

> Installs to `$HOME\.local\bin` by default. Add that directory to your user PATH if needed.

### Quick Start on Windows

```powershell
rtk init --global
# Follow the printed settings.json instructions, then restart Claude Code
```
````

## Recommended INSTALL.md snippet

````md
## Windows Setup

1. Install `rtk.exe` with `install.ps1` or from the GitHub release zip.
2. Run:

   ```powershell
   rtk init --global
   ```

3. Register the generated hook command in `%USERPROFILE%\.claude\settings.json`.
4. Restart Claude Code and test with `git status`.
````

## Recommended ARCHITECTURE.md adjustment

````md
### Platform status

- macOS/Linux: hook-based `rtk init --global` is already first-class.
- Windows: runtime command execution and release binaries exist, but first-class hook setup depends on:
  - a Windows-native hook asset
  - platform-aware init logic
  - a Windows installer
````

## Documentation rule for the implementation PR

Do not document Windows hook support as complete until:

- Phase 1 and Phase 2 have landed
- the Claude Code Windows hook registration format has been confirmed
