#!/usr/bin/env bats
# BTS-21 — drift-watchdog substrate primitives.
#
# Three subcommands:
#   drift-watchdog-list           — JSON array of drifted nodes
#   drift-watchdog-preflight      — JSON {claude_p_available, linear_query_works}
#   drift-watchdog-launchd-print  — macOS launchd .plist on stdout

bats_require_minimum_version 1.5.0

SCRIPT="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/ccanvil-sync.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  HUB=$(mktemp -d)
  mkdir -p "$HUB/.ccanvil"
  cd "$HUB"
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test"
  # Seed a couple of commits so HEAD exists.
  echo "seed" > seed.txt
  git add seed.txt
  git commit -q -m "seed"
  SEED_HASH=$(git rev-parse HEAD)
  echo "second" >> seed.txt
  git add seed.txt
  git commit -q -m "second"
  HEAD_HASH=$(git rev-parse HEAD)
}

teardown() {
  rm -rf "$HUB"
}

_write_registry() {
  cat > "$HUB/.ccanvil/registry.json" <<EOF
$1
EOF
}

# =========================================================================
# AC-1 happy path: empty / no-drift
# =========================================================================

@test "AC-1: empty registry → []" {
  set -e
  _write_registry '{"nodes": {}}'
  run bash "$SCRIPT" drift-watchdog-list
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

@test "AC-1: node with last_synced_version == HEAD → []" {
  set -e
  _write_registry "$(jq -n --arg uuid "node-1" --arg v "$HEAD_HASH" '{
    "nodes": {
      ($uuid): {
        "name": "alpha",
        "path": "/tmp/alpha",
        "registered_at": "1700000000",
        "last_synced": "1700000000",
        "last_synced_version": $v
      }
    }
  }')"
  run bash "$SCRIPT" drift-watchdog-list
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

# =========================================================================
# AC-1 + AC-10 drift detection
# =========================================================================

@test "AC-1: drifted node emits {node_uuid, node_name, drift_key, paths_drifted, commits_behind, summary}" {
  set -e
  # Node's last_synced_version = SEED_HASH (1 commit behind HEAD).
  _write_registry "$(jq -n --arg uuid "node-1" --arg v "$SEED_HASH" '{
    "nodes": {
      ($uuid): {
        "name": "alpha",
        "path": "/tmp/alpha",
        "registered_at": "1700000000",
        "last_synced": "1700000000",
        "last_synced_version": $v
      }
    }
  }')"
  run bash "$SCRIPT" drift-watchdog-list
  [ "$status" -eq 0 ]
  # JSON shape
  echo "$output" | jq -e 'length == 1' >/dev/null
  echo "$output" | jq -e '.[0].node_uuid == "node-1"' >/dev/null
  echo "$output" | jq -e '.[0].node_name == "alpha"' >/dev/null
  echo "$output" | jq -e '.[0].commits_behind == 1' >/dev/null
  echo "$output" | jq -e '.[0].paths_drifted | type == "array"' >/dev/null
  echo "$output" | jq -e '.[0].drift_key | length == 16' >/dev/null
  echo "$output" | jq -e '.[0].summary | type == "string"' >/dev/null
}

@test "AC-1: drift_key is deterministic for same {node, paths}" {
  set -e
  _write_registry "$(jq -n --arg uuid "node-1" --arg v "$SEED_HASH" '{
    "nodes": {
      ($uuid): {
        "name": "alpha",
        "path": "/tmp/alpha",
        "registered_at": "1700000000",
        "last_synced": "1700000000",
        "last_synced_version": $v
      }
    }
  }')"
  local out1 out2
  out1=$(bash "$SCRIPT" drift-watchdog-list | jq -r '.[0].drift_key')
  out2=$(bash "$SCRIPT" drift-watchdog-list | jq -r '.[0].drift_key')
  [ "$out1" = "$out2" ]
}

@test "AC-1: paths_drifted sorted lexicographically" {
  set -e
  # Add a commit touching multiple paths (z, a, m) so we can verify sort.
  echo "z" > z.txt; echo "a" > a.txt; echo "m" > m.txt
  git add z.txt a.txt m.txt
  git commit -q -m "multi"
  HEAD2=$(git rev-parse HEAD)
  _write_registry "$(jq -n --arg uuid "node-1" --arg v "$SEED_HASH" '{
    "nodes": {
      ($uuid): {
        "name": "alpha",
        "path": "/tmp/alpha",
        "registered_at": "1700000000",
        "last_synced": "1700000000",
        "last_synced_version": $v
      }
    }
  }')"
  run bash "$SCRIPT" drift-watchdog-list
  [ "$status" -eq 0 ]
  # Extract paths_drifted; assert sorted ascending.
  local paths sorted
  paths=$(echo "$output" | jq -r '.[0].paths_drifted | join(",")')
  sorted=$(echo "$output" | jq -r '.[0].paths_drifted | sort | join(",")')
  [ "$paths" = "$sorted" ]
}

# =========================================================================
# AC-2: drift-watchdog-list is read-only
# =========================================================================

@test "AC-2: drift-watchdog-list never mutates the script (no git -C writes, no commit invocations)" {
  set -e
  local start end
  start=$(grep -n '^cmd_drift_watchdog_list()' "$SCRIPT" | head -1 | cut -d: -f1)
  [ -n "$start" ]
  end=$(awk -v s="$start" 'NR > s && /^cmd_[a-z_]+\(\)/ { print NR; exit }' "$SCRIPT")
  [ -n "$end" ]
  # Capture the function body once.
  local body
  body=$(sed -n "${start},${end}p" "$SCRIPT")
  ! echo "$body" | grep -qE 'git -C [^ ]+ (commit|add|push|reset|checkout|rm)'
  ! echo "$body" | grep -qE '\bcommit_node_file\b'
  ! echo "$body" | grep -qE '> *.*\.lockfile'
}

# =========================================================================
# AC-6: preflight
# =========================================================================

@test "AC-6: preflight with both checks passing emits {claude_p_available:true, linear_query_works:true}" {
  set -e
  # Stub claude binary and linear-query.sh by prepending PATH.
  local stubs="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$stubs"
  cat > "$stubs/claude" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  chmod +x "$stubs/claude"
  # Override linear-query.sh by setting LINEAR_QUERY_OVERRIDE pointing at a stub.
  cat > "$stubs/linear-query.sh" <<'STUB'
#!/usr/bin/env bash
echo '{"id":"test","name":"Test"}'
exit 0
STUB
  chmod +x "$stubs/linear-query.sh"
  PATH="$stubs:$PATH" CCANVIL_LINEAR_QUERY="$stubs/linear-query.sh" run bash "$SCRIPT" drift-watchdog-preflight
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.claude_p_available == true' >/dev/null
  echo "$output" | jq -e '.linear_query_works == true' >/dev/null
}

@test "AC-6: preflight with claude missing → claude_p_available:false" {
  set -e
  local stubs="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$stubs"
  # No claude stub. Provide working linear-query stub.
  cat > "$stubs/linear-query.sh" <<'STUB'
#!/usr/bin/env bash
echo '{"id":"test","name":"Test"}'
exit 0
STUB
  chmod +x "$stubs/linear-query.sh"
  # PATH excludes /opt/homebrew/bin (where claude lives) — so command -v claude fails.
  # Keep /bin and /usr/bin so jq, sed, awk, etc. still resolve.
  PATH="$stubs:/bin:/usr/bin" CCANVIL_LINEAR_QUERY="$stubs/linear-query.sh" run bash "$SCRIPT" drift-watchdog-preflight
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.claude_p_available == false' >/dev/null
  echo "$output" | jq -e '.linear_query_works == true' >/dev/null
}

@test "AC-6: preflight with linear-query failing → linear_query_works:false" {
  set -e
  local stubs="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$stubs"
  cat > "$stubs/claude" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  chmod +x "$stubs/claude"
  cat > "$stubs/linear-query.sh" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
  chmod +x "$stubs/linear-query.sh"
  PATH="$stubs:$PATH" CCANVIL_LINEAR_QUERY="$stubs/linear-query.sh" run bash "$SCRIPT" drift-watchdog-preflight
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.linear_query_works == false' >/dev/null
}

# =========================================================================
# AC-9: launchd-print
# =========================================================================

@test "AC-9: launchd-print emits a .plist with required fields" {
  set -e
  run bash "$SCRIPT" drift-watchdog-launchd-print
  [ "$status" -eq 0 ]
  echo "$output" | grep -qF '<key>Label</key>'
  echo "$output" | grep -qF 'com.ccanvil.drift-watchdog'
  echo "$output" | grep -qF '<key>StartCalendarInterval</key>'
  echo "$output" | grep -qF '<key>Weekday</key>'
  echo "$output" | grep -qE '<integer>1</integer>'
  echo "$output" | grep -qF '<key>Hour</key>'
  echo "$output" | grep -qE '<integer>9</integer>'
  echo "$output" | grep -qF '<key>Minute</key>'
  echo "$output" | grep -qE '<integer>13</integer>'
  echo "$output" | grep -qF 'claude'
  echo "$output" | grep -qF '/drift-watchdog'
}

@test "AC-9: launchd-print output parses as XML via xmllint" {
  set -e
  if ! command -v xmllint >/dev/null 2>&1; then
    skip "xmllint not available"
  fi
  run bash "$SCRIPT" drift-watchdog-launchd-print
  [ "$status" -eq 0 ]
  echo "$output" | xmllint --noout -
}
