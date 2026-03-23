#!/usr/bin/env bats
# Tests for scripts/operations.sh
#
# Each test creates an isolated project directory with fixture configs.

SCRIPT="$BATS_TEST_DIRNAME/../scripts/operations.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  PROJECT=$(mktemp -d)
}

teardown() {
  rm -rf "$PROJECT"
}

# =========================================================================
# Step 1: Script skeleton + unknown operation error (AC-10)
# =========================================================================

@test "no args prints usage and exits 2" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  echo "$output" | grep -qi "usage"
}

@test "resolve with no operation prints usage and exits 2" {
  run bash "$SCRIPT" resolve
  [ "$status" -eq 2 ]
  echo "$output" | grep -qi "usage"
}

@test "resolve unknown.op exits 1 with error message" {
  run bash "$SCRIPT" resolve unknown.op --project-dir "$PROJECT"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'ERROR: unknown operation "unknown.op"'
}

@test "resolve unknown subcommand exits 2 with usage" {
  run bash "$SCRIPT" badcommand
  [ "$status" -eq 2 ]
  echo "$output" | grep -qi "usage"
}

# =========================================================================
# Step 2: No-config local fallback + invalid JSON error (AC-11, AC-9)
# =========================================================================

@test "resolve backlog.list with no scaffold.json returns local bash adapter" {
  run bash "$SCRIPT" resolve backlog.list --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.provider == "local"'
  echo "$output" | jq -e '.mechanism == "bash"'
  echo "$output" | jq -e '.invocation.command != ""'
  echo "$output" | jq -e '.contract.output | length > 0'
}

@test "resolve backlog.list with invalid JSON exits 1" {
  mkdir -p "$PROJECT/.claude"
  echo "not json" > "$PROJECT/.claude/scaffold.json"
  run bash "$SCRIPT" resolve backlog.list --project-dir "$PROJECT"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'ERROR: .claude/scaffold.json is not valid JSON'
}

@test "resolve backlog.list with empty scaffold.json (no integrations) returns local" {
  mkdir -p "$PROJECT/.claude"
  echo '{}' > "$PROJECT/.claude/scaffold.json"
  run bash "$SCRIPT" resolve backlog.list --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.provider == "local"'
  echo "$output" | jq -e '.mechanism == "bash"'
}
