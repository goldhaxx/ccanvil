#!/usr/bin/env bats
# BTS-605 — drift-guard for broadcast pre-check + registry-prune-stale.
#
# Covers:
#   AC-1: pre-check ignores untracked files (??)
#   AC-2: pre-check still blocks on modified tracked files
#   AC-3: bootstrap-before-dirty reorder with short-circuit semantics
#   AC-4: registry-prune-stale verb (non-dry-run)
#   AC-5: broadcast filters stale entries before iteration
#   AC-9: bootstrap idempotence — no spurious BOOTSTRAPPED when hashes match
#   AC-10: registry-prune-stale --dry-run is byte-identical-read-only

bats_require_minimum_version 1.5.0

# BTS-497 telemetry hooks.
source "$BATS_TEST_DIRNAME/_helpers/telemetry.bash"
setup_file()    { telemetry_setup_file; }
teardown_file() { telemetry_teardown_file; }

SCRIPT="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/ccanvil-sync.sh"

# ---------------------------------------------------------------------------
# Shared fixture: minimal hub + node with full ccanvil-sync init
# (mirrors the ccanvil-sync.bats setup pattern, stripped to essentials)
# ---------------------------------------------------------------------------

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  HUB=$(mktemp -d)
  NODE=$(mktemp -d)

  mkdir -p "$HUB/.claude/rules" "$HUB/.claude/commands" "$HUB/.claude/agents"
  mkdir -p "$HUB/.ccanvil/templates" "$HUB/.ccanvil/scripts" "$HUB/.ccanvil/guide"

  cp "$SCRIPT" "$HUB/.ccanvil/scripts/ccanvil-sync.sh"

  cat > "$HUB/.claude/rules/tdd.md" <<'HUBEOF'
# TDD
<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
HUBEOF

  cat > "$HUB/.ccanvil/guide/index.md" <<'HUBEOF'
# Guide
<!-- NODE-SPECIFIC-START -->
HUBEOF

  cat > "$HUB/CLAUDE.md" <<'HUBEOF'
# Project
<!-- HUB-MANAGED-START -->
## Workflow
HUBEOF

  cat > "$HUB/.ccanvil/templates/CLAUDE.md.fresh" <<'HUBEOF'
# [Project Name]
## Tech Stack
[Tech Stack TBD]
## Commands
[Commands TBD]
## Architecture
[Architecture TBD]
<!-- HUB-MANAGED-START -->
## Workflow
HUBEOF

  git -C "$HUB" init -q
  git -C "$HUB" add -A
  git -C "$HUB" -c user.email=t@t -c user.name=t commit -q -m "init"

  cp -R "$HUB/.claude" "$NODE/.claude"
  mkdir -p "$NODE/.ccanvil/scripts" "$NODE/.ccanvil/guide"
  cp "$SCRIPT" "$NODE/.ccanvil/scripts/ccanvil-sync.sh"
  cp "$HUB/.ccanvil/guide/index.md" "$NODE/.ccanvil/guide/index.md"
  cp "$HUB/CLAUDE.md" "$NODE/CLAUDE.md"

  git -C "$NODE" init -q
  git -C "$NODE" add -A
  git -C "$NODE" -c user.email=t@t -c user.name=t commit -q -m "init node"

  cd "$NODE"
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init "$HUB" >/dev/null 2>&1 || true

  git -C "$NODE" add -A
  git -C "$NODE" -c user.email=t@t -c user.name=t commit -q -m "ccanvil init" 2>/dev/null || true
  git -C "$HUB" add -A 2>/dev/null
  git -C "$HUB" -c user.email=t@t -c user.name=t commit -q -m "register" 2>/dev/null || true
  telemetry_setup
}

teardown() {
  telemetry_teardown
  rm -rf "$HUB" "$NODE"
}

# ---------------------------------------------------------------------------
# AC-1 — pre-check ignores untracked (??)
# ---------------------------------------------------------------------------

@test "AC-1: pre-check passes when node has only an untracked file (e.g. .agents/)" {
  cd "$NODE"
  mkdir -p "$NODE/.agents"
  echo "codex-tooling" > "$NODE/.agents/foo.md"
  # Sanity: confirm the file is untracked (??)
  git -C "$NODE" status --porcelain | grep -q '^??.*\.agents' || skip "fixture: file is not untracked"

  run bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" pre-check
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^OK$'
}

# ---------------------------------------------------------------------------
# AC-2 — pre-check still blocks on modified tracked files
# ---------------------------------------------------------------------------

@test "AC-2: pre-check fails when tracked file is modified, even alongside untracked files" {
  cd "$NODE"
  # Modify a tracked file (CLAUDE.md is tracked post-init).
  echo "tracked-mod" >> "$NODE/CLAUDE.md"
  # Also create an untracked file — the new ignore-?? logic must not suppress
  # the tracked-modification block.
  mkdir -p "$NODE/.codex"
  echo "untracked" > "$NODE/.codex/bar.md"

  run bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" pre-check
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "ERROR: This project has uncommitted changes"
  echo "$output" | grep -q "CLAUDE.md"
}

# ---------------------------------------------------------------------------
# AC-3 — bootstrap-before-dirty reorder, short-circuit semantics pinned
# ---------------------------------------------------------------------------

@test "AC-3: pre-check bootstraps before dirty check — exits 0 even with dirty tracked + untracked" {
  cd "$NODE"

  # Modify HUB's sync script to force hash mismatch.
  echo "# updated for AC-3" >> "$HUB/.ccanvil/scripts/ccanvil-sync.sh"
  git -C "$HUB" add -A
  git -C "$HUB" -c user.email=t@t -c user.name=t commit -q -m "hub update"

  # Modify a tracked file in node (dirty).
  echo "tracked-dirty" >> "$NODE/CLAUDE.md"

  # Also create an untracked Codex artifact.
  mkdir -p "$NODE/.agents"
  echo "codex" > "$NODE/.agents/baz.md"

  run bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" pre-check

  # Pinned semantics: exit 0 + BOOTSTRAPPED: present + ERROR absent.
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "BOOTSTRAPPED:"
  ! echo "$output" | grep -q "ERROR: This project has uncommitted changes"
}

# ---------------------------------------------------------------------------
# AC-9 — bootstrap idempotence (hashes match, only untracked → no spurious BOOTSTRAPPED)
# ---------------------------------------------------------------------------

@test "AC-9: pre-check with matching hashes + only untracked emits OK, not BOOTSTRAPPED" {
  cd "$NODE"
  # Sanity: hashes already match (setup didn't modify either side).
  local hub_h node_h
  hub_h=$(shasum -a 256 "$HUB/.ccanvil/scripts/ccanvil-sync.sh" | awk '{print $1}')
  node_h=$(shasum -a 256 "$NODE/.ccanvil/scripts/ccanvil-sync.sh" | awk '{print $1}')
  [ "$hub_h" = "$node_h" ]

  mkdir -p "$NODE/.codex"
  echo "untracked" > "$NODE/.codex/qux.md"

  run bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" pre-check
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^OK$'
  ! echo "$output" | grep -q "BOOTSTRAPPED"
}

# ---------------------------------------------------------------------------
# Shared helper: build a fixture registry with N real + M stale entries.
# Real entries point to existing tmpdirs; stale entries point to non-existent
# paths. Registry is written to <hub>/.ccanvil/registry.json.
# ---------------------------------------------------------------------------

_seed_registry() {
  local hub="$1"
  local real_path="$2"
  local stale_count="$3"

  local entries='{}'
  # Real entry (one)
  entries=$(echo "$entries" | jq \
    --arg name "real-node" --arg path "$real_path" \
    '. + {"00000000-0000-4000-8000-000000000001": {name: $name, path: $path, registered_at: "1700000000"}}')

  local i
  for ((i=1; i<=stale_count; i++)); do
    local uuid=$(printf "00000000-0000-4000-8000-%012d" "$((100 + i))")
    local nm="tmp.stale${i}"
    local pth="/var/folders/47/nonexistent_$$_${i}/T/tmp.stale${i}"
    entries=$(echo "$entries" | jq --arg u "$uuid" --arg n "$nm" --arg p "$pth" \
      '. + {($u): {name: $n, path: $p, registered_at: "1700000000"}}')
  done

  mkdir -p "$hub/.ccanvil"
  echo "$entries" | jq '{nodes: .}' > "$hub/.ccanvil/registry.json"
}

# ---------------------------------------------------------------------------
# AC-4 — registry-prune-stale verb (non-dry-run)
# ---------------------------------------------------------------------------

@test "AC-4: registry-prune-stale removes only stale entries and returns JSON envelope" {
  # Seed registry with 1 real (the NODE we created) + 3 stale.
  _seed_registry "$HUB" "$NODE" 3

  cd "$HUB"
  run bash "$HUB/.ccanvil/scripts/ccanvil-sync.sh" registry-prune-stale
  [ "$status" -eq 0 ]

  # Validate stdout envelope shape.
  echo "$output" | jq -e '.pruned == 3 and .kept == 1 and .dry_run == false' >/dev/null
  echo "$output" | jq -e '.pruned_names | length == 3 and all(. | startswith("tmp.stale"))' >/dev/null

  # Registry on disk should now have only the real entry.
  local nodes_count
  nodes_count=$(jq '.nodes | length' "$HUB/.ccanvil/registry.json")
  [ "$nodes_count" -eq 1 ]
  jq -e '.nodes["00000000-0000-4000-8000-000000000001"].name == "real-node"' "$HUB/.ccanvil/registry.json" >/dev/null
}

# ---------------------------------------------------------------------------
# AC-10 — registry-prune-stale --dry-run is byte-identical-read-only
# ---------------------------------------------------------------------------

@test "AC-10: registry-prune-stale --dry-run reports prunes but does not mutate the registry file" {
  _seed_registry "$HUB" "$NODE" 3

  local pre_hash post_hash
  pre_hash=$(shasum -a 256 "$HUB/.ccanvil/registry.json" | awk '{print $1}')

  cd "$HUB"
  run bash "$HUB/.ccanvil/scripts/ccanvil-sync.sh" registry-prune-stale --dry-run
  [ "$status" -eq 0 ]

  echo "$output" | jq -e '.pruned == 3 and .kept == 1 and .dry_run == true' >/dev/null

  post_hash=$(shasum -a 256 "$HUB/.ccanvil/registry.json" | awk '{print $1}')
  [ "$pre_hash" = "$post_hash" ]
}

# ---------------------------------------------------------------------------
# AC-5 — broadcast filters stale entries before iteration
# ---------------------------------------------------------------------------

@test "AC-5: broadcast --dry-run emits a single STALE summary, not per-stale headers" {
  _seed_registry "$HUB" "$NODE" 3

  cd "$HUB"
  run bash "$HUB/.ccanvil/scripts/ccanvil-sync.sh" broadcast --dry-run

  # Exactly one summary line for the 3 stale entries.
  local stale_summary_lines
  stale_summary_lines=$(echo "$output" | grep -c "^STALE: 3 entries skipped" || true)
  [ "$stale_summary_lines" -eq 1 ]

  # Zero per-stale === tmp.stale === headers.
  local per_stale_headers
  per_stale_headers=$(echo "$output" | grep -c "^=== tmp\.stale" || true)
  [ "$per_stale_headers" -eq 0 ]

  # One real-node header (its content may then fail later steps, but the header
  # must appear because the entry is live).
  local real_headers
  real_headers=$(echo "$output" | grep -c "^=== real-node" || true)
  [ "$real_headers" -eq 1 ]
}
