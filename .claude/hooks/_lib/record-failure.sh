#!/usr/bin/env bash
# BTS-209: canonical hook-failure recording helper.
#
# Provides _hook_record_failure as a sourceable shell function. Appends one
# JSONL line {ts, hook, step, message} to .ccanvil/state/hook-failures.log
# (gitignored — operator-private failure history).
#
# Contract: telemetry hooks call this on guarded failures (loud, never-block,
# never-snuff). Guard hooks (PreToolUse blockers like protect-files,
# guard-destructive) keep their own blocking contract — this helper is for
# the telemetry-hook surface only.
#
# Usage:
#   source "$CLAUDE_PROJECT_DIR/.claude/hooks/_lib/record-failure.sh"
#   _hook_record_failure "session-boundary" "counter-write" "mktemp failed"
#
# Failures of the helper itself (jq missing, log dir unwritable) are silently
# swallowed — there's no further fallback. Caller already emitted to stderr
# (loud); the durable record is best-effort.

_hook_record_failure() {
  local hook="${1:-unknown}"
  local step="${2:-unknown}"
  local message="${3:-(no message)}"
  local root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  local log_dir="$root/.ccanvil/state"
  local log_file="$log_dir/hook-failures.log"

  mkdir -p "$log_dir" 2>/dev/null || return 0

  local entry
  entry=$(jq -nc \
    --arg hk "$hook" \
    --arg st "$step" \
    --arg msg "$message" \
    --argjson ts "$(date +%s 2>/dev/null || echo 0)" \
    '{ts:$ts, hook:$hk, step:$st, message:$msg}' 2>/dev/null) || return 0

  printf '%s\n' "$entry" >> "$log_file" 2>/dev/null || return 0
  return 0
}
