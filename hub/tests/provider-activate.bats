#!/usr/bin/env bats
#
# BTS-316 Step 4: provider-activate switch.
#
# Composes the existing provider-heal umbrella (auth → drift → resolve-ids)
# with a route-flip step so operators can activate a provider end-to-end with
# one command. Falls back to operator-config team when --team is omitted, and
# to operator-config default_routes when --routes is omitted.

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
  FAKE_HOME="$TMPDIR_BATS/fake-home"
  mkdir -p "$PROJECT_DIR/.claude" "$FAKE_HOME"
  unset LINEAR_API_KEY
  export HOME="$FAKE_HOME"
  cat > "$PROJECT_DIR/.claude/ccanvil.local.json" <<'EOF'
{
  "node_uuid": "deadbeef-aaaa-bbbb-cccc-111122223333",
  "integrations": {
    "routing": {"idea": "local", "spec": "local", "plan": "local", "stasis": "local"},
    "providers": {"linear": {"team": "Foo", "project": "Bar"}}
  }
}
EOF
  CALLS_LOG="$TMPDIR_BATS/calls.log"
  : > "$CALLS_LOG"
  export CALLS_LOG
  telemetry_setup
}

teardown() {
  telemetry_teardown
  [[ -n "${TMPDIR_BATS:-}" ]] && rm -rf "$TMPDIR_BATS"
}

write_lq_stub() {
  local stub="$TMPDIR_BATS/lq-stub.sh"
  cat > "$stub" <<'STUBEOF'
#!/usr/bin/env bash
echo "lq: $*" >> "$CALLS_LOG"
case "$1" in
  viewer) echo '{"id":"VIEWER-1","name":"Stub User"}'; exit 0 ;;
  list-teams) echo '[{"id":"STUB-TEAM-1","name":"Foo"}]'; exit 0 ;;
  list-projects) echo '[{"id":"STUB-PROJ-1","name":"Bar"}]'; exit 0 ;;
  list-states) echo '[{"id":"S-TRI","name":"Triage","type":"triage"},{"id":"S-BAK","name":"Backlog","type":"backlog"},{"id":"S-ICE","name":"Icebox","type":"backlog"},{"id":"S-TODO","name":"Todo","type":"unstarted"},{"id":"S-IP","name":"In Progress","type":"started"},{"id":"S-DONE","name":"Done","type":"completed"},{"id":"S-DUP","name":"Duplicate","type":"canceled"},{"id":"S-CAN","name":"Canceled","type":"canceled"}]'; exit 0 ;;
  list-labels)
    shift
    if [[ "$1" == "--workspace-scoped" ]]; then echo '[{"id":"L-IDEA","name":"idea"}]'
    else echo '[]'; fi
    exit 0 ;;
  *) echo "lq stub: unsupported $1" >&2; exit 2 ;;
esac
STUBEOF
  chmod +x "$stub"
  echo "$stub"
}

write_sync_stub() {
  local stub="$TMPDIR_BATS/sync-stub.sh"
  cat > "$stub" <<'STUBEOF'
#!/usr/bin/env bash
echo "sync: $*" >> "$CALLS_LOG"
case "$1" in
  pull-plan)
    if [[ -n "$STUB_PLAN_JSON" ]]; then echo "$STUB_PLAN_JSON"
    else echo '[]'
    fi
    exit 0 ;;
  pull-auto|pull-apply) echo "sync stub: PROHIBITED CALL: $*" >&2; exit 99 ;;
  *) echo "sync stub: unsupported $1" >&2; exit 2 ;;
esac
STUBEOF
  chmod +x "$stub"
  echo "$stub"
}

init_lock() {
  mkdir -p "$PROJECT_DIR/.ccanvil"
  cat > "$PROJECT_DIR/.ccanvil/ccanvil.lock" <<EOF
{"hub_source": "$TMPDIR_BATS/hub-stub", "hub_version":"stub", "node_uuid":"deadbeef", "files":{}}
EOF
  mkdir -p "$TMPDIR_BATS/hub-stub"
}

# =========================================================================
# AC-7: happy path — all routes flip + IDs resolved
# =========================================================================

@test "BTS-316 AC-7: provider-activate happy path flips all four routes to linear" {
  set -e
  init_lock
  lq=$(write_lq_stub)
  sync=$(write_sync_stub)
  LINEAR_API_KEY="lin_api_x" \
  LINEAR_QUERY_OVERRIDE="$lq" CCANVIL_SYNC_OVERRIDE="$sync" \
    run bash "$SCRIPT" provider-activate --provider linear --team Foo --project Bar \
      --routes spec,plan,stasis,idea --project-dir "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  CFG="$PROJECT_DIR/.claude/ccanvil.local.json"
  for kind in spec plan stasis idea; do
    jq -e --arg k "$kind" '.integrations.routing[$k] == "linear"' "$CFG" >/dev/null
  done
  jq -e '.integrations.providers.linear.team_id == "STUB-TEAM-1"' "$CFG" >/dev/null
  jq -e '.integrations.providers.linear.project_id == "STUB-PROJ-1"' "$CFG" >/dev/null
}

# =========================================================================
# AC-9: idempotency — second run is a no-op (byte-identical config)
# =========================================================================

@test "BTS-316 AC-9: provider-activate idempotency — second run no-op" {
  set -e
  init_lock
  lq=$(write_lq_stub)
  sync=$(write_sync_stub)
  LINEAR_API_KEY="lin_api_x" \
  LINEAR_QUERY_OVERRIDE="$lq" CCANVIL_SYNC_OVERRIDE="$sync" \
    bash "$SCRIPT" provider-activate --provider linear --team Foo --project Bar \
      --routes spec,plan,stasis,idea --project-dir "$PROJECT_DIR"
  cp "$PROJECT_DIR/.claude/ccanvil.local.json" "$TMPDIR_BATS/snapshot.json"
  LINEAR_API_KEY="lin_api_x" \
  LINEAR_QUERY_OVERRIDE="$lq" CCANVIL_SYNC_OVERRIDE="$sync" \
    bash "$SCRIPT" provider-activate --provider linear --team Foo --project Bar \
      --routes spec,plan,stasis,idea --project-dir "$PROJECT_DIR"
  diff -q "$TMPDIR_BATS/snapshot.json" "$PROJECT_DIR/.claude/ccanvil.local.json"
}

# =========================================================================
# AC-10: partial routes — only named kinds flipped
# =========================================================================

@test "BTS-316 AC-10: provider-activate --routes spec,plan flips only named kinds" {
  set -e
  init_lock
  lq=$(write_lq_stub)
  sync=$(write_sync_stub)
  LINEAR_API_KEY="lin_api_x" \
  LINEAR_QUERY_OVERRIDE="$lq" CCANVIL_SYNC_OVERRIDE="$sync" \
    run bash "$SCRIPT" provider-activate --provider linear --team Foo --project Bar \
      --routes spec,plan --project-dir "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  CFG="$PROJECT_DIR/.claude/ccanvil.local.json"
  jq -e '.integrations.routing.spec == "linear"' "$CFG" >/dev/null
  jq -e '.integrations.routing.plan == "linear"' "$CFG" >/dev/null
  jq -e '.integrations.routing.stasis == "local"' "$CFG" >/dev/null
  jq -e '.integrations.routing.idea == "local"' "$CFG" >/dev/null
}

# =========================================================================
# AC-8: operator-config team fallback
# =========================================================================

@test "BTS-316 AC-8: provider-activate falls back to operator-config team" {
  set -e
  init_lock
  bash "$SCRIPT" operator-config init --provider linear --team "Foo"
  lq=$(write_lq_stub)
  sync=$(write_sync_stub)
  LINEAR_API_KEY="lin_api_x" \
  LINEAR_QUERY_OVERRIDE="$lq" CCANVIL_SYNC_OVERRIDE="$sync" \
    run bash "$SCRIPT" provider-activate --provider linear --project Bar \
      --routes spec,idea --project-dir "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  # team passed implicitly — verify by checking that team_id resolved (only happens when team flag eventually reaches provider-resolve-ids)
  CFG="$PROJECT_DIR/.claude/ccanvil.local.json"
  jq -e '.integrations.providers.linear.team_id == "STUB-TEAM-1"' "$CFG" >/dev/null
}

@test "BTS-316 AC-8: provider-activate falls back to operator-config default_routes" {
  set -e
  init_lock
  bash "$SCRIPT" operator-config init --provider linear --team "Foo"
  lq=$(write_lq_stub)
  sync=$(write_sync_stub)
  LINEAR_API_KEY="lin_api_x" \
  LINEAR_QUERY_OVERRIDE="$lq" CCANVIL_SYNC_OVERRIDE="$sync" \
    run bash "$SCRIPT" provider-activate --provider linear --team Foo --project Bar \
      --project-dir "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  # operator-config init seeds default_routes for all four kinds, so all should flip
  CFG="$PROJECT_DIR/.claude/ccanvil.local.json"
  for kind in spec plan stasis idea; do
    jq -e --arg k "$kind" '.integrations.routing[$k] == "linear"' "$CFG" >/dev/null
  done
}

# =========================================================================
# AC-11: phase failures halt without writing routing
# =========================================================================

@test "BTS-316 AC-11: provider-activate auth fail → no routing flip, exit non-zero" {
  init_lock
  lq=$(write_lq_stub)
  sync=$(write_sync_stub)
  # No LINEAR_API_KEY → auth phase fails
  LINEAR_QUERY_OVERRIDE="$lq" CCANVIL_SYNC_OVERRIDE="$sync" \
    run bash "$SCRIPT" provider-activate --provider linear --team Foo --project Bar \
      --routes spec,plan,stasis,idea --project-dir "$PROJECT_DIR"
  [ "$status" -ne 0 ]
  CFG="$PROJECT_DIR/.claude/ccanvil.local.json"
  # Routes must still be local — no half-flipped state
  for kind in spec plan stasis idea; do
    jq -e --arg k "$kind" '.integrations.routing[$k] == "local"' "$CFG" >/dev/null
  done
}

@test "BTS-316 AC-11: provider-activate drift fail → no routing flip" {
  init_lock
  lq=$(write_lq_stub)
  STUB_PLAN_JSON='[{"file":"a.md","action":"auto-update"}]'
  sync=$(STUB_PLAN_JSON="$STUB_PLAN_JSON" write_sync_stub)
  # Drift detected → Phase 2 halts before resolve
  LINEAR_API_KEY="lin_api_x" STUB_PLAN_JSON="$STUB_PLAN_JSON" \
  LINEAR_QUERY_OVERRIDE="$lq" CCANVIL_SYNC_OVERRIDE="$sync" \
    run bash "$SCRIPT" provider-activate --provider linear --team Foo --project Bar \
      --routes spec,plan --project-dir "$PROJECT_DIR"
  [ "$status" -ne 0 ]
  CFG="$PROJECT_DIR/.claude/ccanvil.local.json"
  jq -e '.integrations.routing.spec == "local"' "$CFG" >/dev/null
}

# =========================================================================
# AC-12: --json envelope
# =========================================================================

@test "BTS-316 AC-12: provider-activate --json emits structured envelope on success" {
  set -e
  init_lock
  lq=$(write_lq_stub)
  sync=$(write_sync_stub)
  LINEAR_API_KEY="lin_api_x" \
  LINEAR_QUERY_OVERRIDE="$lq" CCANVIL_SYNC_OVERRIDE="$sync" \
    run bash "$SCRIPT" provider-activate --provider linear --team Foo --project Bar \
      --routes spec,idea --project-dir "$PROJECT_DIR" --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.status == "ok"' >/dev/null
  echo "$output" | jq -e '.provider == "linear"' >/dev/null
  echo "$output" | jq -e '.team == "Foo"' >/dev/null
  echo "$output" | jq -e '.project == "Bar"' >/dev/null
  echo "$output" | jq -e '.routes | length == 2' >/dev/null
  echo "$output" | jq -e '.ids.team_id == "STUB-TEAM-1"' >/dev/null
}

@test "BTS-316 AC-12: provider-activate --json on auth failure emits status=auth-failed" {
  init_lock
  lq=$(write_lq_stub)
  sync=$(write_sync_stub)
  LINEAR_QUERY_OVERRIDE="$lq" CCANVIL_SYNC_OVERRIDE="$sync" \
    run bash "$SCRIPT" provider-activate --provider linear --team Foo --project Bar \
      --routes spec --project-dir "$PROJECT_DIR" --json
  [ "$status" -ne 0 ]
  echo "$output" | jq -e '.status == "auth-failed"' >/dev/null
}

# =========================================================================
# Required-flag validation
# =========================================================================

@test "BTS-316 Step 4: provider-activate without --project errors out" {
  set -e
  init_lock
  bash "$SCRIPT" operator-config init --provider linear --team "Foo"
  lq=$(write_lq_stub)
  sync=$(write_sync_stub)
  LINEAR_API_KEY="lin_api_x" \
  LINEAR_QUERY_OVERRIDE="$lq" CCANVIL_SYNC_OVERRIDE="$sync" \
    run --separate-stderr bash "$SCRIPT" provider-activate --provider linear \
      --routes spec --project-dir "$PROJECT_DIR"
  [ "$status" -ne 0 ]
  echo "$stderr" | grep -q project
}

@test "BTS-316 Step 4: provider-activate without --team and no operator-config team errors" {
  init_lock
  lq=$(write_lq_stub)
  sync=$(write_sync_stub)
  # No operator-config init → no team fallback
  LINEAR_API_KEY="lin_api_x" \
  LINEAR_QUERY_OVERRIDE="$lq" CCANVIL_SYNC_OVERRIDE="$sync" \
    run --separate-stderr bash "$SCRIPT" provider-activate --provider linear --project Bar \
      --routes spec --project-dir "$PROJECT_DIR"
  [ "$status" -ne 0 ]
  echo "$stderr" | grep -q team
}
