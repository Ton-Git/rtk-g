# Phase 6 - Targeted tests

## Goal

Update existing tests in `/home/runner/work/rtk-g/rtk-g/src/init.rs` and add small helper tests so the Windows support changes remain localized and safe.

## Why this phase exists

Current tests hard-code `.sh` assumptions in several places, so they will need to be generalized before Windows support can be added cleanly.

## Current test surface

- `/home/runner/work/rtk-g/rtk-g/src/init.rs:1235+`
- `/home/runner/work/rtk-g/rtk-g/src/init.rs:1336+`
- `/home/runner/work/rtk-g/rtk-g/src/init.rs:1399+`
- `/home/runner/work/rtk-g/rtk-g/src/init.rs:1522+`

## Recommended helper snippet

```rust
#[cfg(windows)]
fn expected_hook_name() -> &'static str {
    "rtk-rewrite.ps1"
}

#[cfg(not(windows))]
fn expected_hook_name() -> &'static str {
    "rtk-rewrite.sh"
}

fn sample_hook_command() -> String {
    format!("/Users/test/.claude/hooks/{}", expected_hook_name())
}
```

## Recommended `init.rs` test updates

```rust
#[test]
fn test_hook_already_present_exact_match() {
    let hook_command = sample_hook_command();
    let json_content = serde_json::json!({
        "hooks": {
            "PreToolUse": [{
                "matcher": "Bash",
                "hooks": [{
                    "type": "command",
                    "command": hook_command
                }]
            }]
        }
    });

    assert!(hook_already_present(&json_content, &sample_hook_command()));
}
```

## Recommended explicit dual-extension coverage

Because `settings.json` cleanup should handle both legacy and Windows commands, add tests that are not platform-gated:

```rust
#[test]
fn test_is_rtk_hook_command_accepts_both_extensions() {
    assert!(is_rtk_hook_command("/tmp/rtk-rewrite.sh"));
    assert!(is_rtk_hook_command("powershell.exe -File C:\\Users\\me\\.claude\\hooks\\rtk-rewrite.ps1"));
    assert!(!is_rtk_hook_command("/tmp/some-other-hook.sh"));
}

#[test]
fn test_remove_hook_from_json_removes_windows_hook_entry() {
    let mut json_content = serde_json::json!({
        "hooks": {
            "PreToolUse": [{
                "matcher": "Bash",
                "hooks": [{
                    "type": "command",
                    "command": "powershell.exe -File C:\\Users\\test\\.claude\\hooks\\rtk-rewrite.ps1"
                }]
            }]
        }
    });

    assert!(remove_hook_from_json(&mut json_content));
}
```

## Recommended validation commands for the implementation PR

```bash
cargo fmt --all --check
cargo clippy --all-targets
cargo test --all
```

## Test strategy note

Prefer helper-based assertions over duplicating `#[cfg]` blocks across many tests. That keeps the Windows support diff in `/home/runner/work/rtk-g/rtk-g/src/init.rs` smaller and easier to review.
