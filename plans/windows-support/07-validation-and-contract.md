# Phase 7 - Validation and external contract check

## Goal

Validate the implementation safely and confirm the one external behavior that cannot be derived from the repository alone: Claude Code’s accepted Windows hook registration format.

## External contract to confirm before or during implementation

For Windows `settings.json`, confirm:

- whether the `matcher` remains `"Bash"`
- whether Claude Code accepts a direct `.ps1` command path
- whether it instead requires `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...`

## Candidate `settings.json` snippets to test

### Option A - direct path

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "C:\\Users\\me\\.claude\\hooks\\rtk-rewrite.ps1"
          }
        ]
      }
    ]
  }
}
```

### Option B - explicit PowerShell wrapper

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\me\\.claude\\hooks\\rtk-rewrite.ps1\""
          }
        ]
      }
    ]
  }
}
```

## Validation checklist for the future implementation PR

1. Run:

   ```bash
   cargo fmt --all --check
   cargo clippy --all-targets
   cargo test --all
   ```

2. Manually verify on Windows:
   - `rtk --version`
   - `rtk init --global`
   - `rtk init --global --show`
   - Claude Code hook registration with the confirmed command shape
   - `git status` gets rewritten through `rtk rewrite`

3. Regression-check Unix behavior:
   - existing `.sh` hook path remains unchanged
   - `rtk init --global` still installs the Bash hook on Unix
   - uninstall/show-config/settings patching still work for legacy `.sh` installs

## Release-readiness notes

- Do not claim Windows support is complete until manual hook registration succeeds on Windows.
- If the accepted Claude Code matcher differs from `"Bash"`, update the Phase 2 plan before coding.
- If PowerShell execution policy affects direct invocation, prefer the explicit wrapper command in `settings.json`.
