#!/usr/bin/env bats
# BTS-320 Phase 2: provider-heal-preflight substrate primitive.
# Read-only gate that runs ccanvil-sync.sh pull-plan and reports drift status.
# No state mutation — does NOT execute pull-auto or pull-apply.

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
  HUB_STUB="$TMPDIR_BATS/hub-stub"
  mkdir -p "$PROJECT_DIR/.ccanvil" "$HUB_STUB"
  cat > "$PROJECT_DIR/.ccanvil/ccanvil.lock" <<EOF
{"hub_source": "$HUB_STUB", "hub_version": "stub", "node_uuid": "deadbeef", "files": {}}
EOF
  CALLS_LOG="$TMPDIR_BATS/sync-calls.log"
  : > "$CALLS_LOG"
  export CALLS_LOG
  telemetry_setup
}

teardown() {
  telemetry_teardown
  [[ -n "${TMPDIR_BATS:-}" ]] && rm -rf "$TMPDIR_BATS"
}

# Stub ccanvil-sync.sh that branches on subcommand. Logs every call to
# $CALLS_LOG so AC-5 can verify pull-auto and pull-apply are never invoked.
write_sync_stub() {
  local stub="$TMPDIR_BATS/sync-stub.sh"
  cat > "$stub" <<'STUBEOF'
#!/usr/bin/env bash
echo "called: $*" >> "$CALLS_LOG"
case "$1" in
  pull-plan)
    if [[ -n "$STUB_PLAN_JSON" ]]; then echo "$STUB_PLAN_JSON"
    else echo '[]'
    fi
    if [[ -n "$STUB_PLAN_EXIT" ]]; then exit "$STUB_PLAN_EXIT"; fi
    exit 0
    ;;
  pull-auto|pull-apply)
    echo "stub: PROHIBITED CALL: $*" >&2
    exit 99
    ;;
  *)
    echo "stub: unsupported subcommand $1" >&2
    exit 2
    ;;
esac
STUBEOF
  chmod +x "$stub"
  echo "$stub"
}

# =========================================================================
# AC-1: empty plan → PREFLIGHT-OK + exit 0
# =========================================================================

@test "AC-1: empty plan exits 0 with PREFLIGHT-OK" {
  set -e
  stub=$(write_sync_stub)
  CCANVIL_SYNC_OVERRIDE="$stub" run bash "$SCRIPT" provider-heal-preflight --project-dir "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qF 'PREFLIGHT-OK: substrate aligned with hub'
}

# =========================================================================
# AC-2: non-zero action counts → exit non-zero + structured stderr
# =========================================================================

@test "AC-2: drift detected → exits non-zero, stderr lists actions + remediation" {
  STUB_PLAN_JSON='[
    {"file":"a.md","action":"auto-update"},
    {"file":"b.md","action":"auto-update"},
    {"file":"c.md","action":"auto-update"},
    {"file":"d.md","action":"new"},
    {"file":"e.md","action":"new"}
  ]'
  stub=$(STUB_PLAN_JSON="$STUB_PLAN_JSON" write_sync_stub)
  STUB_PLAN_JSON="$STUB_PLAN_JSON" CCANVIL_SYNC_OVERRIDE="$stub" run bash "$SCRIPT" provider-heal-preflight --project-dir "$PROJECT_DIR"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qE 'auto-update.*3'
  echo "$output" | grep -qE 'new.*2'
  echo "$output" | grep -qF 'Run /ccanvil-pull'
}

# =========================================================================
# AC-3: missing lock → clear error
# =========================================================================

@test "AC-3: missing ccanvil.lock → exit 1 with init recommendation" {
  rm "$PROJECT_DIR/.ccanvil/ccanvil.lock"
  stub=$(write_sync_stub)
  CCANVIL_SYNC_OVERRIDE="$stub" run bash "$SCRIPT" provider-heal-preflight --project-dir "$PROJECT_DIR"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qE 'ccanvil\.lock missing'
  echo "$output" | grep -qF 'Run /ccanvil-init'
}

# =========================================================================
# AC-4: --json flag → structured envelope
# =========================================================================

@test "AC-4 OK: --json emits status=ok envelope" {
  set -e
  stub=$(write_sync_stub)
  run bash -c "CCANVIL_SYNC_OVERRIDE='$stub' bash '$SCRIPT' provider-heal-preflight --project-dir '$PROJECT_DIR' --json"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.status == "ok"'
  echo "$output" | jq -e '.action_counts.auto_update == 0'
  echo "$output" | jq -e '.hub_path != null'
}

@test "AC-4 DRIFT: --json emits status=drift envelope with counts" {
  STUB_PLAN_JSON='[{"file":"a.md","action":"auto-update"},{"file":"b.md","action":"new"}]'
  stub=$(STUB_PLAN_JSON="$STUB_PLAN_JSON" write_sync_stub)
  run bash -c "STUB_PLAN_JSON='$STUB_PLAN_JSON' CCANVIL_SYNC_OVERRIDE='$stub' bash '$SCRIPT' provider-heal-preflight --project-dir '$PROJECT_DIR' --json"
  [ "$status" -ne 0 ]
  echo "$output" | jq -e '.status == "drift"'
  echo "$output" | jq -e '.action_counts.auto_update == 1'
  echo "$output" | jq -e '.action_counts.new == 1'
}

# =========================================================================
# AC-5: no side-effects — pull-auto + pull-apply never invoked
# =========================================================================

@test "AC-5: substrate never invokes pull-auto or pull-apply" {
  STUB_PLAN_JSON='[{"file":"a.md","action":"auto-update"}]'
  stub=$(STUB_PLAN_JSON="$STUB_PLAN_JSON" write_sync_stub)
  STUB_PLAN_JSON="$STUB_PLAN_JSON" CCANVIL_SYNC_OVERRIDE="$stub" run bash "$SCRIPT" provider-heal-preflight --project-dir "$PROJECT_DIR"
  # Should have invoked pull-plan exactly once
  grep -c 'called: pull-plan' "$CALLS_LOG" | grep -q '^1$'
  # Should NEVER have invoked pull-auto or pull-apply
  ! grep -qE 'called: (pull-auto|pull-apply)' "$CALLS_LOG"
}

# =========================================================================
# AC-6: pull-plan exits non-zero → wrapped as WRAPPER ERROR:
# =========================================================================

@test "AC-6: pull-plan failure surfaces as WRAPPER ERROR:" {
  STUB_PLAN_EXIT=1
  stub=$(STUB_PLAN_EXIT=1 write_sync_stub)
  STUB_PLAN_EXIT=1 CCANVIL_SYNC_OVERRIDE="$stub" run bash "$SCRIPT" provider-heal-preflight --project-dir "$PROJECT_DIR"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qF 'WRAPPER ERROR'
}
