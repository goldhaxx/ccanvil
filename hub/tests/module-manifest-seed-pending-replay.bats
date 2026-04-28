#!/usr/bin/env bats
# BTS-239 Step 8: seed manifest for cmd_idea_pending_replay — AC-7 part 3.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/.ccanvil/scripts/module-manifest.sh"
  TARGET="$REPO_ROOT/.ccanvil/scripts/docs-check.sh"
}

@test "seed/cmd_idea_pending_replay: extract emits a manifest with required fields" {
  set -e
  run bash "$SCRIPT" extract "$TARGET"
  [ "$status" -eq 0 ]
  manifest=$(echo "$output" | jq -c '.[] | select(.id == "cmd_idea_pending_replay")')
  [ -n "$manifest" ]
  echo "$manifest" | jq -e '.purpose | type == "string" and length > 0'
  echo "$manifest" | jq -e '."side-effect" | type == "array" and length > 0'
  echo "$manifest" | jq -e '."failure-mode" | type == "array" and length > 0'
  echo "$manifest" | jq -e '.contract | type == "array" and length > 0'
  echo "$manifest" | jq -e '.anchor | type == "array" and length > 0'
}

@test "seed/cmd_idea_pending_replay: validate exits 0 with seed in allowlist" {
  set -e
  cd "$REPO_ROOT"
  run bash "$SCRIPT" validate --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.coverage.covered >= 3'
  echo "$output" | jq -e '.status == "ok"'
}

@test "seed/cmd_idea_pending_replay: failure-mode markers present in body" {
  set -e
  body_grep() {
    awk '/^cmd_idea_pending_replay\(\)/{f=1} f{print} /^\}/&&f{f=0}' "$TARGET"
  }
  body_grep | grep -qE '^[[:space:]]*#[[:space:]]*@failure-mode:[[:space:]]*usage-error'
  body_grep | grep -qE '^[[:space:]]*#[[:space:]]*@failure-mode:[[:space:]]*replay-dispatch-failure'
}

@test "seed/cmd_idea_pending_replay: side-effect markers present in body" {
  set -e
  body_grep() {
    awk '/^cmd_idea_pending_replay\(\)/{f=1} f{print} /^\}/&&f{f=0}' "$TARGET"
  }
  body_grep | grep -qE '^[[:space:]]*#[[:space:]]*@side-effect:[[:space:]]*rewrites-pending-log'
  body_grep | grep -qE '^[[:space:]]*#[[:space:]]*@side-effect:[[:space:]]*rewrites-emergency-log'
}
