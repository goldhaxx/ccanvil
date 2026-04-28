#!/usr/bin/env bash
# BTS-113 — PreCompact hook. Records epoch timestamp so
# docs-check.sh recommend can distinguish "session about to end (suggest /compact)"
# from "session just resumed after /compact + /recall (suggest forward action)".
#
# BTS-209: migrated to canonical telemetry-hook pattern (loud, never-block,
# never-snuff). Per-step explicit guards + durable failure log via
# _hook_record_failure helper.

set +e

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
STATE_DIR="$ROOT/.ccanvil/state"
MARKER_PATH="$STATE_DIR/last-compact-ts"
HELPER="$ROOT/.claude/hooks/_lib/record-failure.sh"

# Source helper — best-effort. If missing, fall back to stderr-only WARN.
if [[ -f "$HELPER" ]]; then
  source "$HELPER"
else
  _hook_record_failure() { :; }  # no-op fallback
fi

mkdir -p "$STATE_DIR" 2>/dev/null
if [[ ! -d "$STATE_DIR" ]]; then
  echo "WARN: post-compact-marker: cannot create $STATE_DIR" >&2
  _hook_record_failure "post-compact-marker" "mkdir" "cannot create $STATE_DIR"
  exit 0
fi

if ! date +%s > "$MARKER_PATH" 2>/dev/null; then
  echo "WARN: post-compact-marker: cannot write $MARKER_PATH" >&2
  _hook_record_failure "post-compact-marker" "write-marker" "cannot write $MARKER_PATH"
  exit 0
fi

exit 0
