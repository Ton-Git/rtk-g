# Phase 1 - Windows Claude hook asset

## Goal

Add a Windows-native Claude hook at `/home/runner/work/rtk-g/rtk-g/hooks/rtk-rewrite.ps1` while keeping `/home/runner/work/rtk-g/rtk-g/hooks/rtk-rewrite.sh` unchanged.

## Why this phase exists

Today the only bundled hook is `/home/runner/work/rtk-g/rtk-g/hooks/rtk-rewrite.sh`, which depends on Bash and `jq`. Windows needs an additive equivalent that preserves the current thin-hook architecture:

- read hook input JSON from stdin
- extract `.tool_input.command`
- run `rtk rewrite <command>`
- emit updated JSON only when a rewrite happens

## Files involved in the implementation PR

- add `/home/runner/work/rtk-g/rtk-g/hooks/rtk-rewrite.ps1`
- keep `/home/runner/work/rtk-g/rtk-g/hooks/rtk-rewrite.sh` unchanged

## Reference points in the current codebase

- Current Unix hook: `/home/runner/work/rtk-g/rtk-g/hooks/rtk-rewrite.sh`
- Hook embed point: `/home/runner/work/rtk-g/rtk-g/src/init.rs:10`

## Recommended implementation snippet

```powershell
# /home/runner/work/rtk-g/rtk-g/hooks/rtk-rewrite.ps1
# rtk-hook-version: 2

$ErrorActionPreference = "SilentlyContinue"

$jqLikeInput = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($jqLikeInput)) { exit 0 }

$rtk = Get-Command rtk -ErrorAction SilentlyContinue
if (-not $rtk) { exit 0 }

$versionText = & rtk --version 2>$null
if ($versionText -match '(\d+)\.(\d+)\.(\d+)') {
    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    if ($major -eq 0 -and $minor -lt 23) {
        Write-Error "[rtk] WARNING: rtk $($Matches[0]) is too old (need >= 0.23.0)."
        exit 0
    }
}

$payload = $jqLikeInput | ConvertFrom-Json
$command = $payload.tool_input.command
if ([string]::IsNullOrWhiteSpace($command)) { exit 0 }

$rewritten = & rtk rewrite "$command" 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($rewritten)) { exit 0 }
if ($rewritten -eq $command) { exit 0 }

$payload.tool_input.command = $rewritten

[pscustomobject]@{
    hookSpecificOutput = @{
        hookEventName = "PreToolUse"
        permissionDecision = "allow"
        permissionDecisionReason = "RTK auto-rewrite"
        updatedInput = $payload.tool_input
    }
} | ConvertTo-Json -Depth 10 -Compress
```

## Notes for the real implementation

- Keep this hook thin; do not re-implement rewrite rules in PowerShell.
- Use native JSON support instead of adding `jq`-style dependencies.
- Preserve the version gate already present in the shell hook.
- If Claude Code requires a wrapper command instead of a direct `.ps1` hook path, keep the script content the same and adjust registration in Phase 2.

## Open question carried into the next phase

Before shipping, confirm whether Claude Code on Windows accepts:

- a direct `.ps1` command path, or
- a `powershell.exe -File ...` wrapper in `settings.json`
