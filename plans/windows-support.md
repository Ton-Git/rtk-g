# Windows Support Implementation Plan Index

This plan has been split into numbered phase documents so implementation can proceed in small, reviewable steps without changing product code yet.

## Implementation phases

1. [Phase 1 - Windows Claude hook asset](windows-support/01-hook-asset.md) - `/home/runner/work/rtk-g/rtk-g/plans/windows-support/01-hook-asset.md`
2. [Phase 2 - `src/init.rs` platform-aware orchestration](windows-support/02-init-platform-awareness.md) - `/home/runner/work/rtk-g/rtk-g/plans/windows-support/02-init-platform-awareness.md`
3. [Phase 3 - Cross-platform command lookup](windows-support/03-command-lookup.md) - `/home/runner/work/rtk-g/rtk-g/plans/windows-support/03-command-lookup.md`
4. [Phase 4 - Windows installer](windows-support/04-windows-installer.md) - `/home/runner/work/rtk-g/rtk-g/plans/windows-support/04-windows-installer.md`
5. [Phase 5 - Documentation updates](windows-support/05-documentation-updates.md) - `/home/runner/work/rtk-g/rtk-g/plans/windows-support/05-documentation-updates.md`
6. [Phase 6 - Targeted tests](windows-support/06-targeted-tests.md) - `/home/runner/work/rtk-g/rtk-g/plans/windows-support/06-targeted-tests.md`
7. [Phase 7 - Validation and external contract check](windows-support/07-validation-and-contract.md) - `/home/runner/work/rtk-g/rtk-g/plans/windows-support/07-validation-and-contract.md`

## Planning constraints

- Keep `/home/runner/work/rtk-g/rtk-g/hooks/rtk-rewrite.sh` unchanged for Unix users.
- Prefer additive Windows assets over broad refactors.
- Keep rewrite behavior delegated to `rtk rewrite`.
- Do not make functional product changes until the implementation PR.

## Baseline conclusions retained from the original analysis

- The main Windows blockers remain:
  - Unix-only Claude hook asset handling
  - hard-coded `.sh` paths in `/home/runner/work/rtk-g/rtk-g/src/init.rs`
  - Unix-only `which` lookups in runtime code
  - missing Windows-native installer flow
  - docs that still describe Windows as partial/manual support
- Node + TypeScript was considered for a shared Windows hook path and rejected for the initial implementation because this repository is Rust-only and has no existing Node toolchain or `package.json`.
- The lowest-disruption path is still:
  - add a thin Windows-native hook
  - make `/home/runner/work/rtk-g/rtk-g/src/init.rs` platform-aware
  - replace Unix-only command lookup
  - add a Windows installer
  - update docs and tests

## Expected implementation order

1. Add `hooks/rtk-rewrite.ps1`
2. Make `/home/runner/work/rtk-g/rtk-g/src/init.rs` hook selection/path/detection platform-aware
3. Replace Unix-only `which` usage in runtime code
4. Add `install.ps1`
5. Update README/INSTALL/ARCHITECTURE docs
6. Add/update targeted tests
7. Run validation and confirm Claude Code’s Windows hook contract
