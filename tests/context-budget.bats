#!/usr/bin/env bats
# Tests for scripts/context-budget.sh
#
# Each test creates an isolated fixture directory with known file content
# to get deterministic token counts.

SCRIPT="$BATS_TEST_DIRNAME/../scripts/context-budget.sh"

setup() {
  FIXTURE=$(mktemp -d)

  # Create a minimal project structure with known content
  mkdir -p "$FIXTURE/.claude/rules"

  # Project CLAUDE.md — 20 chars = 5 tokens
  printf '12345678901234567890' > "$FIXTURE/CLAUDE.md"

  # One rule file — 8 chars = 2 tokens
  printf '12345678' > "$FIXTURE/.claude/rules/test-rule.md"

  # Settings file — 12 chars = 3 tokens
  printf '{"perms": 1}' > "$FIXTURE/.claude/settings.json"

  # .claudeignore — 4 chars = 1 token
  printf 'dist' > "$FIXTURE/.claudeignore"
}

teardown() {
  rm -rf "$FIXTURE"
}


# =========================================================================
# Step 1: Script skeleton with usage and arg parsing
# =========================================================================

@test "no arguments prints usage and exits 2" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "unknown command prints usage and exits 2" {
  run bash "$SCRIPT" foo
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "check outputs valid JSON" {
  run bash "$SCRIPT" check --project-dir "$FIXTURE"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.' >/dev/null
}

@test "--help prints usage and exits 2" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage:"* ]]
}


# =========================================================================
# Step 2: File discovery and per-file measurement (AC-1, AC-2)
# =========================================================================

@test "check outputs files array with per-file entries" {
  run bash "$SCRIPT" check --project-dir "$FIXTURE"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.files | type == "array"'
  echo "$output" | jq -e '.files | length > 0'
}

@test "each file entry has path, lines, chars, estimated_tokens" {
  run bash "$SCRIPT" check --project-dir "$FIXTURE"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.files[0] | has("path", "lines", "chars", "estimated_tokens")'
}

@test "project CLAUDE.md is measured" {
  run bash "$SCRIPT" check --project-dir "$FIXTURE"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '[.files[] | select(.path | endswith("CLAUDE.md"))] | length > 0'
}

@test "rules files are measured" {
  run bash "$SCRIPT" check --project-dir "$FIXTURE"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '[.files[] | select(.path | contains("rules/"))] | length > 0'
}

@test "settings.json is measured" {
  run bash "$SCRIPT" check --project-dir "$FIXTURE"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '[.files[] | select(.path | endswith("settings.json"))] | length > 0'
}

@test ".claudeignore is measured" {
  run bash "$SCRIPT" check --project-dir "$FIXTURE"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '[.files[] | select(.path | endswith(".claudeignore"))] | length > 0'
}

@test "token estimation uses ceil(chars/4)" {
  # CLAUDE.md has 20 chars → ceil(20/4) = 5 tokens
  run bash "$SCRIPT" check --project-dir "$FIXTURE"
  [ "$status" -eq 0 ]
  local tokens
  tokens=$(echo "$output" | jq '[.files[] | select(.path | endswith("CLAUDE.md"))][0].estimated_tokens')
  [ "$tokens" -eq 5 ]
}

@test "totals object has aggregate lines, chars, estimated_tokens" {
  run bash "$SCRIPT" check --project-dir "$FIXTURE"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.totals | has("lines", "chars", "estimated_tokens")'
}

@test "totals are sum of individual files" {
  run bash "$SCRIPT" check --project-dir "$FIXTURE"
  [ "$status" -eq 0 ]
  # 20 + 8 + 12 + 4 = 44 chars total
  local total_chars
  total_chars=$(echo "$output" | jq '.totals.chars')
  local sum_chars
  sum_chars=$(echo "$output" | jq '[.files[].chars] | add')
  [ "$total_chars" -eq "$sum_chars" ]
}
