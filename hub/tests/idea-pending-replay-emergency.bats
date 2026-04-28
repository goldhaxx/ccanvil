#!/usr/bin/env bats
# BTS-233: /idea sync replays entries from .ccanvil/dual-capture-emergency.log
# in addition to .ccanvil/ideas-pending.log. Auto-recovery for BTS-205's
# emergency dead-letter — closes the dual-capture resilience loop.

bats_require_minimum_version 1.5.0

SCRIPT="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/docs-check.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  PROJECT=$(mktemp -d)
  mkdir -p "$PROJECT/.claude" "$PROJECT/.ccanvil/scripts"
}

teardown() {
  rm -rf "$PROJECT"
}

# Mirror the helpers from idea-pending-replay.bats — Linear-routed config +
# stubbed linear-query.sh. Stub records calls and emits a fake response;
# exit code controls success vs failure.
_with_linear_routing() {
  cat > "$PROJECT/.claude/ccanvil.json" <<'JSON'
{"integrations":{"providers":{"linear":{"mechanism":"mcp"}}}}
JSON
  cat > "$PROJECT/.claude/ccanvil.local.json" <<'JSON'
{"integrations":{"routing":{"idea":"linear"},"providers":{"linear":{"project":"ccanvil","team":"Blocktech","idea_label":"idea","state_ids":{"triage":"TRIAGE-UUID","backlog":"BACKLOG-UUID","icebox":"ICEBOX-UUID","canceled":"CANCELED-UUID","duplicate":"DUPLICATE-UUID"}}}}}
JSON
}

_with_linear_stub() {
  local exit_code="${1:-0}"
  cat > "$PROJECT/.ccanvil/scripts/linear-query.sh" <<EOF
#!/usr/bin/env bash
{
  echo "----CALL----"
  echo "ARGV: \$*"
  echo "STDIN-START"
  cat
  echo "STDIN-END"
} >> "$PROJECT/stub-log"
echo '{"id":"BTS-STUB","title":"stubbed"}'
exit $exit_code
EOF
  chmod +x "$PROJECT/.ccanvil/scripts/linear-query.sh"
}

# =========================================================================
# AC-3: empty/absent emergency log → emergency_pending: 0
# =========================================================================

@test "AC-3: absent emergency log → emergency_pending: 0, no error" {
  set -e
  _with_linear_routing
  _with_linear_stub 0

  run bash "$SCRIPT" idea-pending-replay --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.emergency_pending == 0'
  echo "$output" | jq -e '.synced == 0'
  echo "$output" | jq -e '.failed == 0'
  echo "$output" | jq -e '.pending == 0'
}

@test "AC-3: empty emergency log file → emergency_pending: 0" {
  set -e
  _with_linear_routing
  _with_linear_stub 0
  : > "$PROJECT/.ccanvil/dual-capture-emergency.log"

  run bash "$SCRIPT" idea-pending-replay --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.emergency_pending == 0'
}

# =========================================================================
# AC-4: emergency log with one add entry, dispatch succeeds → log cleared
# =========================================================================

@test "AC-4: emergency add succeeds → log cleared, synced incremented" {
  set -e
  _with_linear_routing
  _with_linear_stub 0
  printf '%s\n' '{"op":"add","args":{"title":"emergency-test","body":"body"},"ts":1234567890}' \
    > "$PROJECT/.ccanvil/dual-capture-emergency.log"

  run bash "$SCRIPT" idea-pending-replay --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.synced == 1'
  echo "$output" | jq -e '.failed == 0'
  echo "$output" | jq -e '.emergency_pending == 0'
  # Log file is cleared
  [ ! -s "$PROJECT/.ccanvil/dual-capture-emergency.log" ]
}

# =========================================================================
# AC-5: emergency log with one add entry, dispatch fails → entry preserved
# =========================================================================

@test "AC-5: emergency add fails → entry preserved, emergency_pending: 1" {
  set -e
  _with_linear_routing
  _with_linear_stub 3   # Non-zero exit → http dispatch failure
  printf '%s\n' '{"op":"add","args":{"title":"emergency-fail","body":"b"},"ts":1234567891}' \
    > "$PROJECT/.ccanvil/dual-capture-emergency.log"

  run bash "$SCRIPT" idea-pending-replay --project-dir "$PROJECT"
  [ "$status" -ne 0 ]   # Non-zero exit when failed > 0 (existing convention)
  echo "$output" | jq -e '.synced == 0'
  echo "$output" | jq -e '.failed == 1'
  echo "$output" | jq -e '.emergency_pending == 1'
  # Log file still has the entry
  [ -s "$PROJECT/.ccanvil/dual-capture-emergency.log" ]
  grep -q '"emergency-fail"' "$PROJECT/.ccanvil/dual-capture-emergency.log"
}

# =========================================================================
# AC-6: both logs populated → counts aggregated, both cleared on success
# =========================================================================

@test "AC-6: both logs with add entries, both succeed → synced: 2, both cleared" {
  set -e
  _with_linear_routing
  _with_linear_stub 0
  printf '%s\n' '{"op":"add","args":{"title":"pending-entry","body":"p"},"ts":1234567892}' \
    > "$PROJECT/.ccanvil/ideas-pending.log"
  printf '%s\n' '{"op":"add","args":{"title":"emergency-entry","body":"e"},"ts":1234567893}' \
    > "$PROJECT/.ccanvil/dual-capture-emergency.log"

  run bash "$SCRIPT" idea-pending-replay --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.synced == 2'
  echo "$output" | jq -e '.failed == 0'
  echo "$output" | jq -e '.pending == 0'
  echo "$output" | jq -e '.emergency_pending == 0'
  [ ! -s "$PROJECT/.ccanvil/ideas-pending.log" ]
  [ ! -s "$PROJECT/.ccanvil/dual-capture-emergency.log" ]
}

# =========================================================================
# Drift-guard: BTS-233 reference inline in docs-check.sh
# =========================================================================

@test "drift: BTS-233 referenced inline in docs-check.sh" {
  grep -q "BTS-233" "$SCRIPT"
}
