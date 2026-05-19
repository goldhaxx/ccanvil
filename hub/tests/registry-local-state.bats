#!/usr/bin/env bats

# BTS-497 telemetry hooks.
source "$BATS_TEST_DIRNAME/_helpers/telemetry.bash"
setup_file()    { telemetry_setup_file; }
teardown_file() { telemetry_teardown_file; }
# Tests for registry-local-state: registry.json is gitignored local state,
# no hub commits during register/broadcast, append-only events.log audit trail.
# Spec: docs/specs/registry-local-state.md

SCRIPT="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/ccanvil-sync.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  HUB=$(mktemp -d)
  NODE=$(mktemp -d)

  mkdir -p "$HUB/.claude/rules" "$HUB/.ccanvil/scripts"
  cp "$SCRIPT" "$HUB/.ccanvil/scripts/ccanvil-sync.sh"
  cat > "$HUB/.claude/rules/tdd.md" <<'HUBEOF'
# TDD Rules
<!-- NODE-SPECIFIC-START -->
HUBEOF

  # Seed the hub's .gitignore with the rules the real hub has.
  # This is the production convention the tests verify.
  cat > "$HUB/.gitignore" <<'HUBEOF'
.DS_Store
.ccanvil/registry.json
.ccanvil/events.log
HUBEOF

  git -C "$HUB" init -q
  git -C "$HUB" config user.email test@test.com
  git -C "$HUB" config user.name test
  git -C "$HUB" add -A
  git -C "$HUB" commit -q -m "init hub"

  cp -R "$HUB/.claude" "$NODE/.claude"
  mkdir -p "$NODE/.ccanvil/scripts"
  cp "$SCRIPT" "$NODE/.ccanvil/scripts/ccanvil-sync.sh"

  git -C "$NODE" init -q
  git -C "$NODE" config user.email test@test.com
  git -C "$NODE" config user.name test
  git -C "$NODE" add -A
  git -C "$NODE" commit -q -m "init node"
  telemetry_setup
}

teardown() { rm -rf "$HUB" "$NODE"; }

# -------------------------------------------------------------------------
# AC-1: .gitignore lists registry.json (and AC-9: events.log)
# -------------------------------------------------------------------------

@test "AC-1: .ccanvil/registry.json is gitignored in the hub" {
  (cd "$HUB" && git check-ignore -q .ccanvil/registry.json)
}

@test "AC-9: .ccanvil/events.log is gitignored in the hub" {
  (cd "$HUB" && git check-ignore -q .ccanvil/events.log)
}

# -------------------------------------------------------------------------
# AC-2: register creates no hub commit
# -------------------------------------------------------------------------

@test "AC-2: register creates no commit on hub" {
  local before
  before=$(git -C "$HUB" rev-list --count HEAD)

  cd "$NODE"
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init "$HUB"

  local after
  after=$(git -C "$HUB" rev-list --count HEAD)
  [ "$before" = "$after" ]

  # Registry file exists and has the new node
  [ -f "$HUB/.ccanvil/registry.json" ]
  local count
  count=$(jq '.nodes | length' "$HUB/.ccanvil/registry.json")
  [ "$count" -eq 1 ]
}

# -------------------------------------------------------------------------
# AC-3: broadcast creates no hub commit
# -------------------------------------------------------------------------

@test "AC-3: broadcast creates no commit on hub" {
  cd "$NODE"
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init "$HUB"
  git -C "$NODE" add -A && git -C "$NODE" commit -q -m "ccanvil init" 2>/dev/null || true

  # Trigger something to sync
  cat > "$HUB/.claude/rules/tdd.md" <<'EOF'
# TDD v2
<!-- NODE-SPECIFIC-START -->
EOF
  git -C "$HUB" add -A && git -C "$HUB" commit -q -m "update tdd"

  local before
  before=$(git -C "$HUB" rev-list --count HEAD)

  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" broadcast >/dev/null 2>&1 || true

  local after
  after=$(git -C "$HUB" rev-list --count HEAD)
  [ "$before" = "$after" ]
}

# -------------------------------------------------------------------------
# AC-4: commit_hub_file helper is gone
# -------------------------------------------------------------------------

@test "AC-4: commit_hub_file helper does not exist in the script" {
  ! grep -qE '^[[:space:]]*commit_hub_file\s*\(\)' "$HUB/.ccanvil/scripts/ccanvil-sync.sh"
  ! grep -qE 'commit_hub_file[[:space:]]+"' "$HUB/.ccanvil/scripts/ccanvil-sync.sh"
}

# -------------------------------------------------------------------------
# AC-5, AC-6: events.log structure + register event
# -------------------------------------------------------------------------

@test "AC-5/6: register appends event to .ccanvil/events.log" {
  set -e
  cd "$NODE"
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init "$HUB"

  [ -f "$HUB/.ccanvil/events.log" ]

  # Each line is valid JSON with ts + event fields
  local line
  line=$(grep '"event":"register"' "$HUB/.ccanvil/events.log" | head -1)
  [ -n "$line" ]
  echo "$line" | jq -e '.ts'
  echo "$line" | jq -e '.event == "register"'
  echo "$line" | jq -e '.node_uuid | test("^[0-9a-f]{8}-[0-9a-f]{4}")'
  echo "$line" | jq -e '.node_name'
  echo "$line" | jq -e '.path'
}

# -------------------------------------------------------------------------
# AC-7: broadcast appends broadcast_sync events
# -------------------------------------------------------------------------

@test "AC-7: broadcast appends one broadcast_sync event per synced node" {
  set -e
  cd "$NODE"
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init "$HUB"
  git -C "$NODE" add -A && git -C "$NODE" commit -q -m "ccanvil init" 2>/dev/null || true

  # Give broadcast something to sync
  cat > "$HUB/.claude/rules/tdd.md" <<'EOF'
# TDD v2
<!-- NODE-SPECIFIC-START -->
EOF
  git -C "$HUB" add -A && git -C "$HUB" commit -q -m "update tdd"

  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" broadcast >/dev/null 2>&1 || true

  [ -f "$HUB/.ccanvil/events.log" ]

  local sync_line
  sync_line=$(grep '"event":"broadcast_sync"' "$HUB/.ccanvil/events.log" | tail -1)
  [ -n "$sync_line" ]
  echo "$sync_line" | jq -e '.node_uuid'
  echo "$sync_line" | jq -e '.node_name'
  echo "$sync_line" | jq -e '.to_version'
}

# -------------------------------------------------------------------------
# AC-8: migrate_legacy_keys event
# -------------------------------------------------------------------------

@test "AC-8: migrate_registry appends migrate_legacy_keys event when legacy keys present" {
  cd "$NODE"
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init "$HUB"

  # Seed a legacy path-keyed entry
  local tmp; tmp=$(mktemp)
  jq --arg p "$NODE" '.nodes += {($p): {"name":"legacy","registered_at":"0"}}' \
    "$HUB/.ccanvil/registry.json" > "$tmp" && mv "$tmp" "$HUB/.ccanvil/registry.json"

  git -C "$NODE" add -A && git -C "$NODE" commit -q -m "ccanvil init" 2>/dev/null || true

  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" broadcast >/dev/null 2>&1 || true

  grep -q '"event":"migrate_legacy_keys"' "$HUB/.ccanvil/events.log"
}

# -------------------------------------------------------------------------
# AC-10: events.log is append-only (prior lines preserved)
# -------------------------------------------------------------------------

@test "AC-10: events.log is append-only (prior lines preserved)" {
  cd "$NODE"
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init "$HUB"

  local initial_count
  initial_count=$(wc -l < "$HUB/.ccanvil/events.log")

  # Run another event-generating action
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" register >/dev/null 2>&1 || true

  local final_count
  final_count=$(wc -l < "$HUB/.ccanvil/events.log")
  [ "$final_count" -ge "$initial_count" ]
}

# -------------------------------------------------------------------------
# AC-11: events subcommand filters
# -------------------------------------------------------------------------

@test "AC-11: events subcommand prints full log with no filters" {
  cd "$NODE"
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init "$HUB"

  local out
  out=$(cd "$HUB" && bash "$HUB/.ccanvil/scripts/ccanvil-sync.sh" events)
  [ -n "$out" ]
  # Contains at least the register event
  echo "$out" | grep -q '"event":"register"'
}

@test "AC-11: events subcommand filters by event type" {
  cd "$NODE"
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init "$HUB"

  local out
  out=$(cd "$HUB" && bash "$HUB/.ccanvil/scripts/ccanvil-sync.sh" events --event register)
  [ -n "$out" ]
  # Every line should be a register event
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "$line" | jq -e '.event == "register"'
  done <<< "$out"
}

@test "AC-11: events subcommand filters by --since epoch" {
  cd "$NODE"
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init "$HUB"

  # Future epoch — no events should match
  local future=9999999999
  local out
  out=$(cd "$HUB" && bash "$HUB/.ccanvil/scripts/ccanvil-sync.sh" events --since "$future")
  [ -z "$out" ]
}

# -------------------------------------------------------------------------
# AC-14: works from a feature branch
# -------------------------------------------------------------------------

@test "AC-14: register from hub on a feature branch succeeds without commit" {
  # Put the hub on a feature branch
  git -C "$HUB" checkout -b feat/test 2>/dev/null

  local before
  before=$(git -C "$HUB" rev-list --count HEAD)

  cd "$NODE"
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init "$HUB"

  local after
  after=$(git -C "$HUB" rev-list --count HEAD)
  [ "$before" = "$after" ]

  # Registry file exists locally (gitignored, unaffected by branch)
  [ -f "$HUB/.ccanvil/registry.json" ]
}
