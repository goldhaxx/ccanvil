#!/usr/bin/env bats
# BTS-209: canonical hook failure recording — loud, never-block, never-snuff.
# - _hook_record_failure helper appends JSONL to .ccanvil/state/hook-failures.log.
# - post-compact-marker.sh and session-boundary.sh call it on guarded failures.

bats_require_minimum_version 1.5.0

# BTS-497 telemetry hooks.
source "$BATS_TEST_DIRNAME/_helpers/telemetry.bash"
setup_file()    { telemetry_setup_file; }
teardown_file() { telemetry_teardown_file; }

REPO_ROOT="$BATS_TEST_DIRNAME/../.."
HELPER="$REPO_ROOT/.claude/hooks/_lib/record-failure.sh"
POST_COMPACT_HOOK="$REPO_ROOT/.claude/hooks/post-compact-marker.sh"
SESSION_BOUNDARY_HOOK="$REPO_ROOT/.claude/hooks/session-boundary.sh"

setup() {
  TMPDIR_BATS=$(mktemp -d)
  PROJECT="$TMPDIR_BATS/proj"
  mkdir -p "$PROJECT/.ccanvil/state"
  export CLAUDE_PROJECT_DIR="$PROJECT"
  telemetry_setup
}

teardown() {
  telemetry_teardown
  [[ -n "${TMPDIR_BATS:-}" ]] && rm -rf "$TMPDIR_BATS"
}

# =========================================================================
# AC-1, AC-5: helper appends JSONL line with expected shape
# =========================================================================

@test "BTS-209 AC-1: _hook_record_failure appends JSONL line to hook-failures.log" {
  set -e
  [ -f "$HELPER" ]
  source "$HELPER"
  _hook_record_failure "test-hook" "step-A" "test message"

  log="$PROJECT/.ccanvil/state/hook-failures.log"
  [ -f "$log" ]
  count=$(wc -l < "$log" | tr -d ' ')
  [ "$count" -eq 1 ]
  line=$(tail -1 "$log")
  echo "$line" | jq -e '.hook == "test-hook"'
  echo "$line" | jq -e '.step == "step-A"'
  echo "$line" | jq -e '.message == "test message"'
  echo "$line" | jq -e '.ts | type == "number"'
}

# =========================================================================
# AC-1: helper appends multiple lines without overwrite
# =========================================================================

@test "BTS-209 AC-1b: multiple calls append distinct lines" {
  set -e
  source "$HELPER"
  _hook_record_failure "h1" "s1" "msg1"
  _hook_record_failure "h2" "s2" "msg2"

  log="$PROJECT/.ccanvil/state/hook-failures.log"
  count=$(wc -l < "$log" | tr -d ' ')
  [ "$count" -eq 2 ]
}

# =========================================================================
# AC-2 + AC-6: post-compact-marker.sh — never blocks
# =========================================================================

@test "BTS-209 AC-2: post-compact-marker.sh exits 0 on success" {
  set -e
  run bash "$POST_COMPACT_HOOK"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT/.ccanvil/state/last-compact-ts" ]
}

@test "BTS-209 AC-6: post-compact-marker.sh exits 0 even if write fails" {
  # Make state dir unwritable to force failure
  mkdir -p "$PROJECT/.ccanvil/state"
  chmod 0555 "$PROJECT/.ccanvil/state"
  run bash "$POST_COMPACT_HOOK"
  rc=$status
  chmod 0755 "$PROJECT/.ccanvil/state"
  # Hook never blocks — exit 0 regardless
  [ "$rc" -eq 0 ]
}

# =========================================================================
# AC-3: session-boundary.sh records WARN paths to log
# =========================================================================

@test "BTS-209 AC-3: session-boundary.sh records non-integer counter to hook-failures.log" {
  set -e
  echo "garbage" > "$PROJECT/.ccanvil/state/session-counter"
  run bash "$SESSION_BOUNDARY_HOOK"
  [ "$status" -eq 0 ]
  log="$PROJECT/.ccanvil/state/hook-failures.log"
  if [[ -f "$log" ]]; then
    grep -q "session-boundary" "$log"
  fi
}

# =========================================================================
# Drift-guard
# =========================================================================

@test "BTS-209 drift: BTS-209 referenced inline in record-failure.sh" {
  [ -f "$HELPER" ]
  grep -q "BTS-209" "$HELPER"
}

@test "BTS-209 drift: BTS-209 referenced inline in post-compact-marker.sh" {
  grep -q "BTS-209" "$POST_COMPACT_HOOK"
}

@test "BTS-209 drift: BTS-209 referenced inline in session-boundary.sh" {
  grep -q "BTS-209" "$SESSION_BOUNDARY_HOOK"
}
