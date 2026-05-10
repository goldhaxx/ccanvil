#!/usr/bin/env bats
# BTS-419 — substrate-staleness drift-guard.
#
# Asserts that linear_assert_project_id_emitted enforces the contract:
# "if project_id is configured, the resolved command for any project-scoped
# verb MUST contain --project-id". Hard-fail with ALLOW_STALE_SUBSTRATE=1
# bypass.

bats_require_minimum_version 1.5.0

OPS="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/operations.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  PROJECT=$(mktemp -d)
  mkdir -p "$PROJECT/.claude"
}

teardown() {
  rm -rf "$PROJECT"
}

# ===========================================================================
# Step 1 — helper exists, clean pass-through paths
# ===========================================================================

@test "BTS-419 Step 1a: linear_assert_project_id_emitted is defined" {
  source "$OPS"
  declare -F linear_assert_project_id_emitted >/dev/null
}

@test "BTS-419 Step 1b: helper passes through when project_id is empty" {
  source "$OPS"
  input='{"invocation":{"command":"bash linear-query.sh list-issues --team T"}}'
  output=$(linear_assert_project_id_emitted "backlog.list" "" "$input")
  [ "$output" = "$input" ]
}

@test "BTS-419 Step 1c: helper passes through when command already has --project-id" {
  source "$OPS"
  input='{"invocation":{"command":"bash linear-query.sh list-issues --project-id UUID --team T"}}'
  output=$(linear_assert_project_id_emitted "backlog.list" "UUID" "$input")
  [ "$output" = "$input" ]
}

# ===========================================================================
# Step 2 — fire path: project_id set + command lacks --project-id → ERROR
# ===========================================================================

@test "BTS-419 Step 2a: helper fires with non-zero exit when project_id set but --project-id missing" {
  source "$OPS"
  input='{"invocation":{"command":"bash linear-query.sh list-issues --team T"}}'
  run linear_assert_project_id_emitted "backlog.list" "UUID-1" "$input"
  [ "$status" -ne 0 ]
}

@test "BTS-419 Step 2b: fire path stderr contains 'stale substrate'" {
  source "$OPS"
  input='{"invocation":{"command":"bash linear-query.sh list-issues --team T"}}'
  run linear_assert_project_id_emitted "backlog.list" "UUID-1" "$input"
  [[ "$output" == *"stale substrate"* ]]
}

@test "BTS-419 Step 2c: fire path stderr names the remediation recipe" {
  source "$OPS"
  input='{"invocation":{"command":"bash linear-query.sh list-issues --team T"}}'
  run linear_assert_project_id_emitted "backlog.list" "UUID-1" "$input"
  [[ "$output" == *"ccanvil-sync.sh pull"* ]]
}

# ===========================================================================
# Step 3 — AC-7 operator-grade message: project_id value, verb name, cd recipe
# ===========================================================================

@test "BTS-419 Step 3a: fire path stderr contains the literal project_id value" {
  source "$OPS"
  input='{"invocation":{"command":"bash linear-query.sh list-issues --team T"}}'
  run linear_assert_project_id_emitted "backlog.list" "PROJ-UUID-XYZ" "$input"
  [[ "$output" == *"PROJ-UUID-XYZ"* ]]
}

@test "BTS-419 Step 3b: fire path stderr names the verb being resolved" {
  source "$OPS"
  input='{"invocation":{"command":"bash linear-query.sh list-issues --team T"}}'
  run linear_assert_project_id_emitted "idea.review-icebox" "UUID-1" "$input"
  [[ "$output" == *"idea.review-icebox"* ]]
}

@test "BTS-419 Step 3c: fire path stderr includes a 'cd' recipe prefix" {
  source "$OPS"
  input='{"invocation":{"command":"bash linear-query.sh list-issues --team T"}}'
  run linear_assert_project_id_emitted "backlog.list" "UUID-1" "$input"
  [[ "$output" == *"cd "* ]]
}

# ===========================================================================
# Step 4 — AC-5: no fire on non-project-scoped verbs (ticket.transition,
# work.resolve). These verbs operate on a single ticket identifier; the
# project filter is not part of their contract surface, so the guard must
# NOT fire even when project_id is configured.
# ===========================================================================

_with_linear_routing_and_project_id() {
  cat > "$PROJECT/.claude/ccanvil.json" <<'JSON'
{"integrations":{"providers":{"linear":{"mechanism":"mcp"}}}}
JSON
  cat > "$PROJECT/.claude/ccanvil.local.json" <<'JSON'
{"integrations":{"routing":{"idea":"linear"},"providers":{"linear":{"project_id":"PROJ-UUID-1","team":"Blocktech Solutions","idea_label":"idea","state_ids":{"done":"STATE-DONE","backlog":"STATE-BL","todo":"STATE-TD","in_progress":"STATE-IP"}}}}}
JSON
}

@test "BTS-419 Step 4a: ticket.transition does NOT trigger staleness guard when project_id is set" {
  _with_linear_routing_and_project_id
  run bash "$OPS" resolve ticket.transition BTS-100 done --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"stale substrate"* ]]
  # Sanity: the resolved command is the canonical save-issue shape, no project filter.
  echo "$output" | jq -e '.invocation.command | contains("save-issue") and contains("STATE-DONE")'
}

@test "BTS-419 Step 4b: work.resolve does NOT trigger staleness guard when project_id is set" {
  _with_linear_routing_and_project_id
  run bash "$OPS" resolve work.resolve BTS-100 --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"stale substrate"* ]]
}

# ===========================================================================
# Step 5 — ALLOW_STALE_SUBSTRATE=1 bypass: operator-controlled emergency
# escape valve. Matches the ALLOW_DESTRUCTIVE / ALLOW_MAIN / ALLOW_OUTSIDE
# pattern. Bypass turns the hard-fail into a pass-through; a single-line
# WARN: advisory may go to stderr (informational, not blocking).
# ===========================================================================

@test "BTS-419 Step 5a: ALLOW_STALE_SUBSTRATE=1 turns the hard-fail into pass-through" {
  source "$OPS"
  input='{"invocation":{"command":"bash linear-query.sh list-issues --team T"}}'
  ALLOW_STALE_SUBSTRATE=1 output=$(linear_assert_project_id_emitted "backlog.list" "UUID-1" "$input")
  [ "$output" = "$input" ]
}

@test "BTS-419 Step 5b: ALLOW_STALE_SUBSTRATE=1 exits 0 (not 1)" {
  source "$OPS"
  input='{"invocation":{"command":"bash linear-query.sh list-issues --team T"}}'
  ALLOW_STALE_SUBSTRATE=1 run linear_assert_project_id_emitted "backlog.list" "UUID-1" "$input"
  [ "$status" -eq 0 ]
}

@test "BTS-419 Step 5c: ALLOW_STALE_SUBSTRATE=1 does not emit 'stale substrate' ERROR text" {
  source "$OPS"
  input='{"invocation":{"command":"bash linear-query.sh list-issues --team T"}}'
  ALLOW_STALE_SUBSTRATE=1 run linear_assert_project_id_emitted "backlog.list" "UUID-1" "$input"
  [[ "$output" != *"ERROR: stale substrate"* ]]
}

# ===========================================================================
# Step 7 — AC-1 verb-loop positive fixture. With project_id configured and
# project (name) empty, EACH of the six project-scoped verbs MUST emit
# --project-id in its resolved command. End-to-end via operations.sh resolve.
# ===========================================================================

_with_project_id_only() {
  cat > "$PROJECT/.claude/ccanvil.json" <<'JSON'
{"integrations":{"providers":{"linear":{"mechanism":"mcp"}}}}
JSON
  cat > "$PROJECT/.claude/ccanvil.local.json" <<'JSON'
{"integrations":{"routing":{"idea":"linear"},"providers":{"linear":{"project_id":"PROJ-UUID-LOOP","team":"Blocktech Solutions","idea_label":"idea","state_ids":{"backlog":"S-BL","triage":"S-TR","icebox":"S-IB"}}}}}
JSON
}

@test "BTS-419 Step 7a: backlog.list emits --project-id (project_id-only config)" {
  _with_project_id_only
  run bash "$OPS" resolve backlog.list --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.invocation.command | contains("--project-id ")'
}

@test "BTS-419 Step 7b: idea.add emits --project-id (project_id-only config)" {
  _with_project_id_only
  run bash "$OPS" resolve idea.add --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.invocation.command | contains("--project-id ")'
}

@test "BTS-419 Step 7c: idea.list emits --project-id (project_id-only config)" {
  _with_project_id_only
  run bash "$OPS" resolve idea.list --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.invocation.command | contains("--project-id ")'
}

@test "BTS-419 Step 7d: idea.count emits --project-id (project_id-only config)" {
  _with_project_id_only
  run bash "$OPS" resolve idea.count --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.invocation.command | contains("--project-id ")'
}

@test "BTS-419 Step 7e: idea.triage emits --project-id (project_id-only config)" {
  _with_project_id_only
  run bash "$OPS" resolve idea.triage --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.invocation.command | contains("--project-id ")'
}

@test "BTS-419 Step 7f: idea.review-icebox emits --project-id (project_id-only config)" {
  _with_project_id_only
  run bash "$OPS" resolve idea.review-icebox --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.invocation.command | contains("--project-id ")'
}

# ===========================================================================
# Step 8 — AC-2 no-empty-flag emission. With NEITHER project_id NOR project
# set, the resolved command MUST NOT carry the empty-value forms
# `--project ''` or `--project-id ''`. Mirrors BTS-407 AC-5 across all 6 verbs.
# ===========================================================================

_with_neither_project() {
  cat > "$PROJECT/.claude/ccanvil.json" <<'JSON'
{"integrations":{"providers":{"linear":{"mechanism":"mcp"}}}}
JSON
  cat > "$PROJECT/.claude/ccanvil.local.json" <<'JSON'
{"integrations":{"routing":{"idea":"linear"},"providers":{"linear":{"team":"Blocktech Solutions","idea_label":"idea","state_ids":{"backlog":"S-BL","triage":"S-TR","icebox":"S-IB"}}}}}
JSON
}

@test "BTS-419 Step 8a: backlog.list emits no empty --project / --project-id flag" {
  _with_neither_project
  run bash "$OPS" resolve backlog.list --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  cmd=$(echo "$output" | jq -r '.invocation.command')
  [[ "$cmd" != *"--project ''"* ]]
  [[ "$cmd" != *"--project-id ''"* ]]
}

@test "BTS-419 Step 8b: idea.add emits no empty --project / --project-id flag" {
  _with_neither_project
  run bash "$OPS" resolve idea.add --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  cmd=$(echo "$output" | jq -r '.invocation.command')
  [[ "$cmd" != *"--project ''"* ]]
  [[ "$cmd" != *"--project-id ''"* ]]
}

@test "BTS-419 Step 8c: idea.list emits no empty --project / --project-id flag" {
  _with_neither_project
  run bash "$OPS" resolve idea.list --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  cmd=$(echo "$output" | jq -r '.invocation.command')
  [[ "$cmd" != *"--project ''"* ]]
  [[ "$cmd" != *"--project-id ''"* ]]
}

@test "BTS-419 Step 8d: idea.count emits no empty --project / --project-id flag" {
  _with_neither_project
  run bash "$OPS" resolve idea.count --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  cmd=$(echo "$output" | jq -r '.invocation.command')
  [[ "$cmd" != *"--project ''"* ]]
  [[ "$cmd" != *"--project-id ''"* ]]
}

@test "BTS-419 Step 8e: idea.triage emits no empty --project / --project-id flag" {
  _with_neither_project
  run bash "$OPS" resolve idea.triage --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  cmd=$(echo "$output" | jq -r '.invocation.command')
  [[ "$cmd" != *"--project ''"* ]]
  [[ "$cmd" != *"--project-id ''"* ]]
}

@test "BTS-419 Step 8f: idea.review-icebox emits no empty --project / --project-id flag" {
  _with_neither_project
  run bash "$OPS" resolve idea.review-icebox --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  cmd=$(echo "$output" | jq -r '.invocation.command')
  [[ "$cmd" != *"--project ''"* ]]
  [[ "$cmd" != *"--project-id ''"* ]]
}
