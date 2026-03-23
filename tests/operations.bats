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

# =========================================================================
# Step 3: Full operations taxonomy — all 17 local resolves (AC-1)
# =========================================================================

@test "all 17 operations resolve to local bash adapter with no config" {
  local ops=(
    backlog.list backlog.create backlog.prioritize backlog.get
    spec.read spec.write spec.list spec.activate spec.complete
    plan.read plan.write
    checkpoint.read checkpoint.write
    status.get status.update
    pr.create pr.list
    review.run
  )
  for op in "${ops[@]}"; do
    run bash "$SCRIPT" resolve "$op" --project-dir "$PROJECT"
    [ "$status" -eq 0 ] || { echo "FAIL: $op exited $status"; return 1; }
    echo "$output" | jq -e '.provider == "local"' || { echo "FAIL: $op provider != local"; return 1; }
    echo "$output" | jq -e '.mechanism == "bash"' || { echo "FAIL: $op mechanism != bash"; return 1; }
    echo "$output" | jq -e '.invocation.command != ""' || { echo "FAIL: $op empty command"; return 1; }
    echo "$output" | jq -e '.contract.output | length > 0' || { echo "FAIL: $op empty contract"; return 1; }
  done
}

@test "backlog.list local command references docs-check.sh list-specs" {
  run bash "$SCRIPT" resolve backlog.list --project-dir "$PROJECT"
  echo "$output" | jq -e '.invocation.command | test("docs-check.sh list-specs")'
}

@test "spec.read local command references docs/spec.md" {
  run bash "$SCRIPT" resolve spec.read --project-dir "$PROJECT"
  echo "$output" | jq -e '.invocation.command | test("spec.md")'
}

@test "plan.read local command references docs/plan.md" {
  run bash "$SCRIPT" resolve plan.read --project-dir "$PROJECT"
  echo "$output" | jq -e '.invocation.command | test("plan.md")'
}

@test "checkpoint.read local command references docs/checkpoint.md" {
  run bash "$SCRIPT" resolve checkpoint.read --project-dir "$PROJECT"
  echo "$output" | jq -e '.invocation.command | test("checkpoint.md")'
}

@test "status.get local command references docs-check.sh" {
  run bash "$SCRIPT" resolve status.get --project-dir "$PROJECT"
  echo "$output" | jq -e '.invocation.command | test("docs-check.sh")'
}

@test "pr.create local command references gh pr create" {
  run bash "$SCRIPT" resolve pr.create --project-dir "$PROJECT"
  echo "$output" | jq -e '.invocation.command | test("gh pr create")'
}

# =========================================================================
# Step 4: MCP resolve for backlog.list (AC-2)
# =========================================================================

@test "backlog.list with linear routing returns MCP adapter" {
  mkdir -p "$PROJECT/.claude"
  cat > "$PROJECT/.claude/scaffold.json" <<'JSON'
{
  "integrations": {
    "providers": {
      "linear": {
        "mechanism": "mcp",
        "project": "Test Project",
        "team": "Test Team"
      }
    },
    "routing": {
      "backlog": "linear"
    }
  }
}
JSON
  run bash "$SCRIPT" resolve backlog.list --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.provider == "linear"'
  echo "$output" | jq -e '.mechanism == "mcp"'
  echo "$output" | jq -e '.invocation.tool == "mcp__claude_ai_Linear__list_issues"'
  echo "$output" | jq -e '.invocation.params.project == "Test Project"'
  echo "$output" | jq -e '.invocation.params.team == "Test Team"'
  echo "$output" | jq -e '.contract.output | length > 0'
}
