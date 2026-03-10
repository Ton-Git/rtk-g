# rtk-hook-version: 2
# RTK Claude Code hook — rewrites commands to use rtk for token savings.
# Requires: rtk >= 0.23.0, PowerShell
#
# This is a thin delegating hook: all rewrite logic lives in `rtk rewrite`,
# which is the single source of truth (src/discover/registry.rs).
# To add or change rewrite rules, edit the Rust registry — not this file.

$ErrorActionPreference = "Stop"

try {
    $inputJson = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($inputJson)) {
        exit 0
    }

    $rtk = Get-Command rtk -ErrorAction SilentlyContinue
    if (-not $rtk) {
        exit 0
    }

    $versionText = & rtk --version 2>$null
    if ($versionText -match '(\d+)\.(\d+)\.(\d+)') {
        $major = [int]$Matches[1]
        $minor = [int]$Matches[2]

        if ($major -eq 0 -and $minor -lt 23) {
            Write-Error "[rtk] WARNING: rtk $($Matches[0]) is too old (need >= 0.23.0). Upgrade: cargo install rtk"
            exit 0
        }
    }

    $payload = $inputJson | ConvertFrom-Json
    $command = $payload.tool_input.command
    if ([string]::IsNullOrWhiteSpace($command)) {
        exit 0
    }

    $rewritten = (& rtk rewrite "$command" 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($rewritten)) {
        exit 0
    }

    if ($rewritten -eq $command) {
        exit 0
    }

    $payload.tool_input.command = $rewritten

    [pscustomobject]@{
        hookSpecificOutput = @{
            hookEventName = "PreToolUse"
            permissionDecision = "allow"
            permissionDecisionReason = "RTK auto-rewrite"
            updatedInput = $payload.tool_input
        }
    } | ConvertTo-Json -Depth 10 -Compress
} catch {
    exit 0
}
