#!/usr/bin/env bats
# BTS-207: cmd_session_info reads boundary state in at most one jq fork.
# Replaces the prior 5-fork pattern (validity check + 3 field reads + assembly).

bats_require_minimum_version 1.5.0

# BTS-497 telemetry hooks.
source "$BATS_TEST_DIRNAME/_helpers/telemetry.bash"
setup_file()    { telemetry_setup_file; }
teardown_file() { telemetry_teardown_file; }

REPO_ROOT="$BATS_TEST_DIRNAME/../.."
SCRIPT="$REPO_ROOT/.ccanvil/scripts/docs-check.sh"

setup() {
  TMPDIR_BATS=$(mktemp -d)
  PROJECT_DIR="$TMPDIR_BATS/proj"
  mkdir -p "$PROJECT_DIR/.ccanvil/state"
  COUNT_FILE="$TMPDIR_BATS/jq-call-count"
  echo "0" > "$COUNT_FILE"
  # Capture real jq path BEFORE shadowing.
  REAL_JQ=$(command -v jq)
  telemetry_setup
}

teardown() {
  telemetry_teardown
  [[ -n "${TMPDIR_BATS:-}" ]] && rm -rf "$TMPDIR_BATS"
}

# Counted-jq wrapper: increments $COUNT_FILE on each invocation, then runs real jq.
write_counted_jq() {
  local wrapper="$TMPDIR_BATS/counted-jq.sh"
  cat > "$wrapper" <<EOF
#!/usr/bin/env bash
n=\$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
echo \$((n + 1)) > "$COUNT_FILE"
exec "$REAL_JQ" "\$@"
EOF
  chmod +x "$wrapper"
  echo "$wrapper"
}

# Build a PATH-shadow directory exporting our counted jq first.
shadow_path_with_counted_jq() {
  local jq_wrapper="$1"
  local shadow_dir="$TMPDIR_BATS/bin"
  mkdir -p "$shadow_dir"
  ln -s "$jq_wrapper" "$shadow_dir/jq"
  echo "$shadow_dir"
}

# =========================================================================
# AC-1 + AC-4: valid boundary → ≤1 jq invocation
# =========================================================================

@test "BTS-207 AC-1: valid boundary → cmd_session_info uses at most 1 jq fork" {
  set -e
  echo "5" > "$PROJECT_DIR/.ccanvil/state/session-counter"
  jq -n --arg ts "2099-01-01T00:00:00-08:00" --arg tz "America/Los_Angeles" \
    '{epoch:9999999999, iso:$ts, tz:$tz}' > "$PROJECT_DIR/.ccanvil/state/session-boundary"

  jq_counter=$(write_counted_jq)
  shadow=$(shadow_path_with_counted_jq "$jq_counter")

  PATH="$shadow:$PATH" run bash "$SCRIPT" session-info --project-dir "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.counter == 5'
  echo "$output" | jq -e '.epoch == 9999999999'

  count=$(cat "$COUNT_FILE")
  if (( count > 1 )); then
    echo "FAIL: cmd_session_info forked jq $count times (expected ≤1)" >&2
    return 1
  fi
}

# =========================================================================
# AC-2 + AC-4: missing boundary → ≤1 jq invocation
# =========================================================================

@test "BTS-207 AC-2: missing boundary → cmd_session_info uses at most 1 jq fork" {
  set -e
  echo "0" > "$PROJECT_DIR/.ccanvil/state/session-counter"
  # No boundary file written.

  jq_counter=$(write_counted_jq)
  shadow=$(shadow_path_with_counted_jq "$jq_counter")

  PATH="$shadow:$PATH" run bash "$SCRIPT" session-info --project-dir "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.counter == 0'
  echo "$output" | jq -e '.epoch == null'

  count=$(cat "$COUNT_FILE")
  if (( count > 1 )); then
    echo "FAIL: cmd_session_info forked jq $count times for missing boundary (expected ≤1)" >&2
    return 1
  fi
}

# =========================================================================
# AC-2 + AC-4: corrupt boundary → ≤1 jq invocation
# =========================================================================

@test "BTS-207 AC-2b: corrupt boundary → cmd_session_info uses at most 1 jq fork" {
  set -e
  echo "3" > "$PROJECT_DIR/.ccanvil/state/session-counter"
  echo "not-valid-json" > "$PROJECT_DIR/.ccanvil/state/session-boundary"

  jq_counter=$(write_counted_jq)
  shadow=$(shadow_path_with_counted_jq "$jq_counter")

  PATH="$shadow:$PATH" run bash "$SCRIPT" session-info --project-dir "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.counter == 3'
  echo "$output" | jq -e '.epoch == null'

  count=$(cat "$COUNT_FILE")
  if (( count > 1 )); then
    echo "FAIL: cmd_session_info forked jq $count times for corrupt boundary (expected ≤1)" >&2
    return 1
  fi
}

# =========================================================================
# AC-3: output shape preserved
# =========================================================================

@test "BTS-207 AC-3: output JSON shape is unchanged from BTS-206 baseline" {
  set -e
  echo "9" > "$PROJECT_DIR/.ccanvil/state/session-counter"
  jq -n --arg iso "2099-04-01T08:00:00-07:00" --arg tz "America/Los_Angeles" \
    '{epoch:1234567890, iso:$iso, tz:$tz}' > "$PROJECT_DIR/.ccanvil/state/session-boundary"

  run bash "$SCRIPT" session-info --project-dir "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.counter == 9'
  echo "$output" | jq -e '.epoch == 1234567890'
  echo "$output" | jq -e '.iso == "2099-04-01T08:00:00-07:00"'
  echo "$output" | jq -e '.tz == "America/Los_Angeles"'
}

# =========================================================================
# Drift-guard
# =========================================================================

@test "BTS-207 drift: BTS-207 referenced inline in docs-check.sh" {
  grep -q "BTS-207" "$SCRIPT"
}
