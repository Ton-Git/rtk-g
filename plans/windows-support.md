# Windows Support Analysis Plan

## Goal

Add **full Windows support** for RTK with the **smallest possible change set**, favoring **new additive assets** (PowerShell hook/installer/docs) over broad refactors. The current codebase is already close to Windows-ready: release packaging exists, several command runners already use `cmd` on Windows, and path storage relies on cross-platform crates. The remaining gaps are concentrated in the **Claude Code hook/bootstrap flow**, **Unix-only command discovery**, and **Windows-specific installation documentation**.

## Baseline findings

### Already working or largely cross-platform

- **Windows release artifacts already exist** in `/home/runner/work/rtk-g/rtk-g/.github/workflows/release.yml`.
- **Command execution already branches for Windows** in:
  - `/home/runner/work/rtk-g/rtk-g/src/runner.rs`
  - `/home/runner/work/rtk-g/rtk-g/src/summary.rs`
- **Data/config paths already use cross-platform helpers** (`dirs`/`PathBuf`) in modules such as:
  - `/home/runner/work/rtk-g/rtk-g/src/init.rs`
  - `/home/runner/work/rtk-g/rtk-g/src/config.rs`
  - `/home/runner/work/rtk-g/rtk-g/src/tracking.rs`

### Current Windows blockers

1. **`rtk init` intentionally downgrades on non-Unix**
   - `/home/runner/work/rtk-g/rtk-g/src/init.rs:658-664`
   - Today Windows cannot use hook-first mode; it falls back to `--claude-md`.

2. **The only bundled Claude hook is a shell script**
   - `/home/runner/work/rtk-g/rtk-g/hooks/rtk-rewrite.sh`
   - Embedded from `/home/runner/work/rtk-g/rtk-g/src/init.rs:10`
   - It depends on Unix shell semantics and `jq`.

3. **Hook path handling is hard-coded to `rtk-rewrite.sh`**
   - `/home/runner/work/rtk-g/rtk-g/src/init.rs:185-191`
   - Multiple install/show/uninstall/settings.json code paths look for `.sh` specifically.

4. **Several runtime code paths use the Unix `which` command**
   - These will fail on stock Windows shells unless replaced with a cross-platform lookup strategy.

5. **The top-level installer is Linux/macOS-only**
   - `/home/runner/work/rtk-g/rtk-g/install.sh`
   - Uses `uname`, `tar`, POSIX shell flow, and no Windows branch.

6. **Docs still describe Windows as binary download / CLAUDE.md fallback rather than first-class hook support**
   - `/home/runner/work/rtk-g/rtk-g/README.md`
   - `/home/runner/work/rtk-g/rtk-g/INSTALL.md`
   - `/home/runner/work/rtk-g/rtk-g/ARCHITECTURE.md`

## Proposed implementation strategy

### Design principle

Prefer this shape:

- **Add** Windows-specific assets:
  - `hooks/rtk-rewrite.ps1`
  - `install.ps1`
- Make **small, localized Rust changes** only where the current code hard-codes Unix assumptions.
- Avoid touching filtering logic or unrelated command modules unless they currently fail only because of Unix-only tool detection.

## Required change points

### 1) Claude Code hook asset for Windows

#### New file to add

- `/home/runner/work/rtk-g/rtk-g/hooks/rtk-rewrite.ps1`

#### Why it is needed

Windows currently has no hook asset that can be installed by `rtk init -g`. The existing hook is:

- shell-specific (`#!/usr/bin/env bash`)
- dependent on `jq`
- named and referenced as `.sh` everywhere

#### Expected behavior

The PowerShell hook should mirror the current shell hook:

- read the JSON payload from stdin
- extract `.tool_input.command`
- no-op if `rtk` is unavailable
- version-gate `rtk rewrite`
- run `rtk rewrite <cmd>`
- emit the updated Claude hook response JSON when a rewrite occurs

#### Recommended implementation notes

- Keep the hook **thin**, as with the existing shell version.
- Avoid extra dependencies if possible; PowerShell’s native JSON conversion should replace `jq`.
- Preserve the existing “delegate to `rtk rewrite`” architecture.

### 2) `src/init.rs` must become hook-platform-aware

This is the main Rust orchestration surface and the biggest source of hard-coded Unix assumptions.

#### File to change

- `/home/runner/work/rtk-g/rtk-g/src/init.rs`

#### Required sub-changes

1. **Embed the right hook asset per platform**
   - Current: `include_str!("../hooks/rtk-rewrite.sh")`
   - Needed: a Windows-aware selection between `.sh` and `.ps1`

2. **Choose the correct hook filename**
   - Current hard-coded filename:
     - `rtk-rewrite.sh` in `prepare_hook_paths()`
   - Needed:
     - `.sh` on Unix
     - `.ps1` on Windows

3. **Install hook on Windows instead of forcing `--claude-md`**
   - Current fallback:
     - `/home/runner/work/rtk-g/rtk-g/src/init.rs:658-664`
   - Needed:
     - Windows should use hook-first mode if the PowerShell hook is available.

4. **Avoid Unix-only permission logic on Windows**
   - `ensure_hook_installed()` is currently `#[cfg(unix)]` and sets `0o755`
   - Needed:
     - Windows path that writes the hook without Unix permission handling
     - integrity hash behavior should remain aligned if integrity checks still apply there

5. **Patch `settings.json` using the Windows hook command**
   - `patch_settings_json()`, `insert_hook_entry()`, and manual instructions must point to the correct hook path/command.
   - If Claude Code on Windows requires a specific command wrapper (for example `powershell -File ...`), that needs to be encoded here.
   - This is the one area that should be verified against Claude Code’s Windows hook expectations before implementation.

6. **Hook detection/removal must stop matching only `.sh`**
   - Functions/paths impacted:
     - hook detection in settings.json
     - uninstall flow
     - show-config flow
     - tests that assert `rtk-rewrite.sh`

#### Specific `src/init.rs` areas that will need updating

- embedded hook constant: `:10`
- path creation: `:185-191`
- settings cleanup matching `.sh`: `:357`, `:634-654`
- uninstall hook path: `:423`
- non-Unix default mode fallback: `:658-664`
- show-config hook path: `:1012`
- tests that assert `.sh` paths/content:
  - `:1235+`
  - `:1342+`
  - `:1360+`
  - `:1400+`
  - `:1536+`

### 3) Replace Unix-only runtime command lookup

The current implementation assumes `which` exists. That is not true on Windows. This affects actual RTK command behavior, not just helper scripts.

#### Best minimal approach

Use one shared cross-platform lookup mechanism in Rust, then update all `which` callers to use it.

Two acceptable options:

1. **Preferred:** add the `which` crate and centralize lookup in a helper.
2. **Alternative:** implement a small internal helper using `PATH`/PATHEXT`.

The first option is simpler and less error-prone, but it is a new dependency and should be kept localized.

#### Files with user/runtime impact

- `/home/runner/work/rtk-g/rtk-g/src/utils.rs`
  - `package_manager_exec()` currently probes with `Command::new("which")`
- `/home/runner/work/rtk-g/rtk-g/src/tsc_cmd.rs`
- `/home/runner/work/rtk-g/rtk-g/src/prisma_cmd.rs`
- `/home/runner/work/rtk-g/rtk-g/src/next_cmd.rs`
- `/home/runner/work/rtk-g/rtk-g/src/pytest_cmd.rs`
- `/home/runner/work/rtk-g/rtk-g/src/mypy_cmd.rs`
- `/home/runner/work/rtk-g/rtk-g/src/pip_cmd.rs`
- `/home/runner/work/rtk-g/rtk-g/src/ccusage.rs`
- `/home/runner/work/rtk-g/rtk-g/src/tree.rs`

#### Notes

- `tree` may still not exist on Windows by default; that is fine if RTK reports a good installation hint.
- The goal here is to remove the **false negative caused by `which`**, not to guarantee every external tool is bundled with Windows.

### 4) Windows installer

#### New file to add

- `/home/runner/work/rtk-g/rtk-g/install.ps1`

#### Why it is needed

The current installer is explicitly Linux/macOS-only:

- `/home/runner/work/rtk-g/rtk-g/install.sh`

Windows users currently have to manually find the release zip or rely on Cargo. Adding a PowerShell installer is the cleanest additive way to make Windows feel first-class.

#### Expected behavior

- detect architecture
- resolve latest release
- download `rtk-x86_64-pc-windows-msvc.zip`
- extract `rtk.exe`
- install into a user-local bin directory
- print PATH instructions if needed

#### Recommended path target

Plan on a Windows-appropriate user bin location such as one of:

- `%USERPROFILE%\\.local\\bin`
- `%USERPROFILE%\\bin`

The exact target should match whatever the docs recommend and should be consistent with PATH guidance.

### 5) Documentation updates for first-class Windows support

#### Files to update

- `/home/runner/work/rtk-g/rtk-g/README.md`
- `/home/runner/work/rtk-g/rtk-g/INSTALL.md`
- `/home/runner/work/rtk-g/rtk-g/ARCHITECTURE.md`

#### Required content changes

1. **README**
   - Add a Windows install path alongside Linux/macOS quick install.
   - Document `rtk init -g` as supported on Windows once hook support lands.
   - Add PowerShell examples for install/verification where appropriate.

2. **INSTALL.md**
   - Add a dedicated Windows installation/setup section.
   - Update hook paths/examples from “Unix only” to platform-aware wording.
   - Replace Windows guidance that currently implies `--claude-md` is the only full option.
   - Include PowerShell equivalents for restore/edit commands where examples are currently shell-only.

3. **ARCHITECTURE.md**
   - The current “works on macOS, Linux, Windows without modification” statement should be reconciled with the current reality and then updated once Windows hook support is actually complete.

#### Additional docs to consider

- `/home/runner/work/rtk-g/rtk-g/CLAUDE.md`
  - only if contributor instructions explicitly describe Windows as unsupported in `init`
- localized READMEs
  - optional follow-up, not required for the first Windows-support pass

### 6) Tests that should be added or updated

The user asked for analysis first, but implementation will need targeted tests to keep the changes safe.

#### Primary test surface

- `/home/runner/work/rtk-g/rtk-g/src/init.rs` existing tests

#### Required test updates

- replace `.sh`-specific assumptions with platform-aware helpers or separate Unix/Windows cases
- add tests for hook path generation:
  - Unix => `rtk-rewrite.sh`
  - Windows => `rtk-rewrite.ps1`
- add tests for settings.json detection/removal that work for both hook extensions
- add tests for show/uninstall logic if helper functions are extracted

#### Additional targeted tests

- command lookup helper tests, especially if a new shared helper is introduced
- potentially an install-script smoke test if the repo already has a pattern for script validation

## Optional but lower-priority follow-up work

These are useful, but they are **not required** to declare end-user Windows support for RTK itself.

### Contributor/developer script parity

Many scripts under `/home/runner/work/rtk-g/rtk-g/scripts` are still Bash-oriented. Notable examples:

- `check-installation.sh` uses `which`
- `test-all.sh`, `benchmark.sh`, `install-local.sh`, `rtk-economics.sh` are shell-first

Recommended status:

- **Do not block initial Windows support on these.**
- If desired later, add Windows-specific companions such as:
  - `check-installation.ps1`
  - `install-local.ps1`

### Package-manager distribution on Windows

Potential future additions:

- WinGet manifest
- Chocolatey package

Nice-to-have only; not required for the initial issue.

## Suggested implementation order

1. Add `hooks/rtk-rewrite.ps1`
2. Make `/src/init.rs` hook selection/path/detection platform-aware
3. Replace Unix-only `which` usage in runtime code
4. Add `install.ps1`
5. Update README/INSTALL/ARCHITECTURE docs
6. Add/update targeted tests
7. Validate:
   - `cargo fmt --all --check`
   - `cargo clippy --all-targets`
   - `cargo test --all`
   - manual `rtk init -g --show` verification on Windows if available

## Expected scope

### Additions

- `/home/runner/work/rtk-g/rtk-g/hooks/rtk-rewrite.ps1`
- `/home/runner/work/rtk-g/rtk-g/install.ps1`

### Minimal code changes

- `/home/runner/work/rtk-g/rtk-g/src/init.rs`
- a small set of runtime lookup call sites or one shared helper plus its callers
- documentation files listed above

## Open question to resolve before implementation

The only external behavior that should be confirmed before coding is **how Claude Code expects command hooks to be registered on Windows**:

- whether the `matcher` remains `"Bash"`
- whether the hook command can be a direct `.ps1` path
- or whether it must be wrapped via `powershell.exe -File ...`

Everything else can be implemented from the current codebase with small, localized changes.
