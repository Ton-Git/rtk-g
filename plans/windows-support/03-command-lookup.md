# Phase 3 - Cross-platform command lookup

## Goal

Replace Unix-only `which` process calls in runtime code with a cross-platform lookup mechanism that works on Windows.

## Why this phase exists

Current code probes commands using `Command::new("which")`, which will fail on stock Windows environments even when the target tool is actually installed.

## Current call sites to update later

- `/home/runner/work/rtk-g/rtk-g/src/utils.rs:231-259`
- `/home/runner/work/rtk-g/rtk-g/src/tsc_cmd.rs`
- `/home/runner/work/rtk-g/rtk-g/src/prisma_cmd.rs`
- `/home/runner/work/rtk-g/rtk-g/src/next_cmd.rs`
- `/home/runner/work/rtk-g/rtk-g/src/pytest_cmd.rs`
- `/home/runner/work/rtk-g/rtk-g/src/mypy_cmd.rs`
- `/home/runner/work/rtk-g/rtk-g/src/pip_cmd.rs`
- `/home/runner/work/rtk-g/rtk-g/src/ccusage.rs`
- `/home/runner/work/rtk-g/rtk-g/src/tree.rs`

## Recommended minimal implementation direction

Keep the change localized by introducing one helper in `/home/runner/work/rtk-g/rtk-g/src/utils.rs` and using it everywhere else.

## Recommended helper snippet

```rust
use std::env;
use std::path::{Path, PathBuf};

pub fn command_exists(cmd: &str) -> bool {
    find_command_in_path(cmd).is_some()
}

pub fn find_command_in_path(cmd: &str) -> Option<PathBuf> {
    let path_var = env::var_os("PATH")?;

    #[cfg(windows)]
    let exts: Vec<String> = env::var("PATHEXT")
        .unwrap_or(".COM;.EXE;.BAT;.CMD".to_string())
        .split(';')
        .map(|s| s.to_ascii_lowercase())
        .collect();

    for dir in env::split_paths(&path_var) {
        #[cfg(windows)]
        {
            let candidate = dir.join(cmd);
            if candidate.is_file() {
                return Some(candidate);
            }

            for ext in &exts {
                let suffix = ext.trim_start_matches('.');
                let candidate = dir.join(format!("{cmd}.{suffix}"));
                if candidate.is_file() {
                    return Some(candidate);
                }
            }
        }

        #[cfg(not(windows))]
        {
            let candidate = dir.join(cmd);
            if candidate.is_file() {
                return Some(candidate);
            }
        }
    }

    None
}
```

## Example conversion in `/home/runner/work/rtk-g/rtk-g/src/utils.rs`

Current shape:

```rust
let tool_exists = Command::new("which")
    .arg(tool)
    .output()
    .map(|o| o.status.success())
    .unwrap_or(false);
```

Recommended replacement:

```rust
let tool_exists = command_exists(tool);
```

## Example conversion in tool-specific modules

```rust
fn which_command(cmd: &str) -> Option<String> {
    crate::utils::find_command_in_path(cmd)
        .map(|path| path.display().to_string())
}
```

## Special note for `tree`

`tree` still may not be installed on Windows by default. That is acceptable. The goal is:

- stop failing because `which` is missing
- keep existing “tool not installed” messaging when the tool truly is absent

## Optional alternative

If a tiny external dependency is acceptable in the implementation PR, the `which` crate could replace the helper above. The dependency-free helper is included here because it avoids changing `/home/runner/work/rtk-g/rtk-g/Cargo.toml`.
