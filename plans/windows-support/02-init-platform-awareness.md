# Phase 2 - `src/init.rs` platform-aware orchestration

## Goal

Make `/home/runner/work/rtk-g/rtk-g/src/init.rs` select the correct hook asset, path, and settings registration strategy on each platform without rewriting the existing Unix flow.

## Why this phase exists

The largest Windows gap is in `/home/runner/work/rtk-g/rtk-g/src/init.rs`, which currently hard-codes:

- `include_str!("../hooks/rtk-rewrite.sh")`
- `rtk-rewrite.sh` in hook paths
- non-Unix fallback to `--claude-md`
- `.sh`-specific detection/removal logic in `settings.json`

## Current code locations to update later

- `/home/runner/work/rtk-g/rtk-g/src/init.rs:10`
- `/home/runner/work/rtk-g/rtk-g/src/init.rs:185-191`
- `/home/runner/work/rtk-g/rtk-g/src/init.rs:357`
- `/home/runner/work/rtk-g/rtk-g/src/init.rs:423`
- `/home/runner/work/rtk-g/rtk-g/src/init.rs:634-654`
- `/home/runner/work/rtk-g/rtk-g/src/init.rs:658-664`
- `/home/runner/work/rtk-g/rtk-g/src/init.rs:1012`

## Recommended helper structure

```rust
#[cfg(windows)]
const REWRITE_HOOK: &str = include_str!("../hooks/rtk-rewrite.ps1");

#[cfg(not(windows))]
const REWRITE_HOOK: &str = include_str!("../hooks/rtk-rewrite.sh");

fn hook_filename() -> &'static str {
    #[cfg(windows)]
    {
        "rtk-rewrite.ps1"
    }

    #[cfg(not(windows))]
    {
        "rtk-rewrite.sh"
    }
}

fn prepare_hook_paths() -> Result<(PathBuf, PathBuf)> {
    let claude_dir = resolve_claude_dir()?;
    let hook_dir = claude_dir.join("hooks");
    fs::create_dir_all(&hook_dir)
        .with_context(|| format!("Failed to create hook directory: {}", hook_dir.display()))?;
    let hook_path = hook_dir.join(hook_filename());
    Ok((hook_dir, hook_path))
}
```

## Recommended install/write split

```rust
#[cfg(unix)]
fn ensure_hook_installed(hook_path: &Path, verbose: u8) -> Result<bool> {
    let changed = write_if_changed(hook_path, REWRITE_HOOK, "hook", verbose)?;

    use std::os::unix::fs::PermissionsExt;
    fs::set_permissions(hook_path, fs::Permissions::from_mode(0o755))
        .with_context(|| format!("Failed to set hook permissions: {}", hook_path.display()))?;

    integrity::store_hash(hook_path)
        .with_context(|| format!("Failed to store integrity hash for {}", hook_path.display()))?;

    Ok(changed)
}

#[cfg(windows)]
fn ensure_hook_installed(hook_path: &Path, verbose: u8) -> Result<bool> {
    let changed = write_if_changed(hook_path, REWRITE_HOOK, "hook", verbose)?;
    integrity::store_hash(hook_path)
        .with_context(|| format!("Failed to store integrity hash for {}", hook_path.display()))?;
    Ok(changed)
}
```

## Recommended hook-command registration helper

```rust
fn hook_command_for_settings(hook_path: &Path) -> String {
    #[cfg(windows)]
    {
        format!(
            "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"{}\"",
            hook_path.display()
        )
    }

    #[cfg(not(windows))]
    {
        hook_path.display().to_string()
    }
}

fn is_rtk_hook_command(command: &str) -> bool {
    command.contains("rtk-rewrite.sh") || command.contains("rtk-rewrite.ps1")
}
```

## Recommended `settings.json` integration updates

```rust
fn hook_already_present(root: &serde_json::Value, hook_command: &str) -> bool {
    let pre_tool_use_array = match root
        .get("hooks")
        .and_then(|h| h.get("PreToolUse"))
        .and_then(|p| p.as_array())
    {
        Some(arr) => arr,
        None => return false,
    };

    pre_tool_use_array
        .iter()
        .filter_map(|entry| entry.get("hooks")?.as_array())
        .flatten()
        .filter_map(|hook| hook.get("command")?.as_str())
        .any(|cmd| cmd == hook_command || (is_rtk_hook_command(cmd) && is_rtk_hook_command(hook_command)))
}

fn remove_hook_from_json(root: &mut serde_json::Value) -> bool {
    let hooks = match root.get_mut("hooks").and_then(|h| h.get_mut("PreToolUse")) {
        Some(pre_tool_use) => pre_tool_use,
        None => return false,
    };

    let pre_tool_use_array = match hooks.as_array_mut() {
        Some(arr) => arr,
        None => return false,
    };

    let original_len = pre_tool_use_array.len();
    pre_tool_use_array.retain(|entry| {
        !entry
            .get("hooks")
            .and_then(|h| h.as_array())
            .into_iter()
            .flatten()
            .filter_map(|hook| hook.get("command")?.as_str())
            .any(is_rtk_hook_command)
    });

    pre_tool_use_array.len() < original_len
}
```

## Recommended default-mode shape

```rust
fn run_default_mode(global: bool, patch_mode: PatchMode, verbose: u8) -> Result<()> {
    if !global {
        return run_claude_md_mode(false, verbose);
    }

    let claude_dir = resolve_claude_dir()?;
    let rtk_md_path = claude_dir.join("RTK.md");
    let claude_md_path = claude_dir.join("CLAUDE.md");

    let (_hook_dir, hook_path) = prepare_hook_paths()?;
    let hook_changed = ensure_hook_installed(&hook_path, verbose)?;

    write_if_changed(&rtk_md_path, RTK_SLIM, "RTK.md", verbose)?;
    let migrated = patch_claude_md(&claude_md_path, verbose)?;
    let patch_result = patch_settings_json(&hook_path, patch_mode, verbose)?;

    // Reuse existing success output, but platform-aware hook path/command.
    // This keeps Unix behavior stable and removes the Windows fallback.
    Ok(())
}
```

## Important constraint

Do not change the Unix hook workflow beyond replacing hard-coded `.sh` strings with platform-aware helpers.

## External dependency to confirm before coding

The `matcher` and `command` shape in Claude Code `settings.json` on Windows still needs confirmation. The Rust helpers above should be adjusted only after that contract is verified.
