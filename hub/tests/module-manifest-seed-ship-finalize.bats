#!/usr/bin/env bats
# BTS-239 Step 7: seed manifest for cmd_ship_finalize — AC-7 part 2.

load _helpers/manifest-validate-cache

setup_file() {
  manifest_validate_cache_setup_file
}

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/.ccanvil/scripts/module-manifest.sh"
  TARGET="$REPO_ROOT/.ccanvil/scripts/docs-check.sh"
  manifest_validate_cache_setup
}

@test "seed/cmd_ship_finalize: extract emits a manifest with required fields" {
  set -e
  run bash "$SCRIPT" extract "$TARGET"
  [ "$status" -eq 0 ]
  manifest=$(echo "$output" | jq -c '.[] | select(.id == "cmd_ship_finalize")')
  [ -n "$manifest" ]
  echo "$manifest" | jq -e '.purpose | type == "string" and length > 0'
  echo "$manifest" | jq -e '.input | type == "array" and length > 0'
  echo "$manifest" | jq -e '.output | type == "array" and length > 0'
  echo "$manifest" | jq -e '."side-effect" | type == "array" and length > 0'
  echo "$manifest" | jq -e '."failure-mode" | type == "array" and length > 0'
  echo "$manifest" | jq -e '.contract | type == "array" and length > 0'
  echo "$manifest" | jq -e '.anchor | type == "array" and length > 0'
}

@test "seed/cmd_ship_finalize: validate exits 0 with seed in allowlist" {
  set -e
  # BTS-281: read cached validate JSON (run once per file in setup_file).
  output=$(cat "$MANIFEST_VALIDATE_JSON")
  echo "$output" | jq -e '.coverage.covered >= 2'
  echo "$output" | jq -e '.status == "ok"'
}

@test "seed/cmd_ship_finalize: failure-mode markers present in body" {
  set -e
  body_grep() {
    awk '/^cmd_ship_finalize\(\)/{f=1} f{print} /^\}/&&f{f=0}' "$TARGET"
  }
  body_grep | grep -qE '^[[:space:]]*#[[:space:]]*@failure-mode:[[:space:]]*usage-error'
  body_grep | grep -qE '^[[:space:]]*#[[:space:]]*@failure-mode:[[:space:]]*preflight-error'
  body_grep | grep -qE '^[[:space:]]*#[[:space:]]*@failure-mode:[[:space:]]*title-error'
  body_grep | grep -qE '^[[:space:]]*#[[:space:]]*@failure-mode:[[:space:]]*ready-error'
  body_grep | grep -qE '^[[:space:]]*#[[:space:]]*@failure-mode:[[:space:]]*merge-error'
}

@test "seed/cmd_ship_finalize: side-effect markers present in body" {
  set -e
  body_grep() {
    awk '/^cmd_ship_finalize\(\)/{f=1} f{print} /^\}/&&f{f=0}' "$TARGET"
  }
  body_grep | grep -qE '^[[:space:]]*#[[:space:]]*@side-effect:[[:space:]]*merges-pr'
  body_grep | grep -qE '^[[:space:]]*#[[:space:]]*@side-effect:[[:space:]]*updates-pr-title'
  body_grep | grep -qE '^[[:space:]]*#[[:space:]]*@side-effect:[[:space:]]*marks-pr-ready'
  body_grep | grep -qE '^[[:space:]]*#[[:space:]]*@side-effect:[[:space:]]*fast-forwards-main'
  body_grep | grep -qE '^[[:space:]]*#[[:space:]]*@side-effect:[[:space:]]*transitions-linear-ticket'
  body_grep | grep -qE '^[[:space:]]*#[[:space:]]*@side-effect:[[:space:]]*queues-pending-on-failure'
}
