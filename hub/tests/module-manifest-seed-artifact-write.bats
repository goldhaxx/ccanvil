#!/usr/bin/env bats
# BTS-239 Step 6: seed manifest for cmd_artifact_write — AC-7 part 1.

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

@test "seed/cmd_artifact_write: extract emits a manifest with required fields" {
  set -e
  run bash "$SCRIPT" extract "$TARGET"
  [ "$status" -eq 0 ]
  manifest=$(echo "$output" | jq -c '.[] | select(.id == "cmd_artifact_write")')
  [ -n "$manifest" ]
  echo "$manifest" | jq -e '.purpose | type == "string" and length > 0'
  echo "$manifest" | jq -e '.input | type == "array" and length > 0'
  echo "$manifest" | jq -e '.output | type == "array" and length > 0'
  echo "$manifest" | jq -e '."side-effect" | type == "array" and length > 0'
  echo "$manifest" | jq -e '."failure-mode" | type == "array" and length > 0'
  echo "$manifest" | jq -e '.contract | type == "array" and length > 0'
  echo "$manifest" | jq -e '.anchor | type == "array" and length > 0'
}

@test "seed/cmd_artifact_write: validate exits 0 against project allowlist" {
  set -e
  # BTS-281: read cached validate JSON (run once per file in setup_file).
  output=$(cat "$MANIFEST_VALIDATE_JSON")
  echo "$output" | jq -e '.coverage.covered >= 1'
  echo "$output" | jq -e '.status == "ok"'
}

@test "seed/cmd_artifact_write: declared callers actually invoke the primitive" {
  set -e
  run bash "$SCRIPT" extract "$TARGET"
  manifest=$(echo "$output" | jq -c '.[] | select(.id == "cmd_artifact_write")')
  callers=$(echo "$manifest" | jq -r '.caller[]')
  [ -n "$callers" ]
  # BTS-281: read cached validate JSON (run once per file in setup_file).
  cat "$MANIFEST_VALIDATE_JSON" | jq -e '.coverage.covered >= 1'
}

@test "seed/cmd_artifact_write: failure-mode markers exist in body" {
  set -e
  body_grep() {
    awk '/^cmd_artifact_write\(\)/{f=1} f{print} /^\}/&&f{f=0}' "$TARGET"
  }
  body_grep | grep -qE '^[[:space:]]*#[[:space:]]*@failure-mode:[[:space:]]*validation-error'
  body_grep | grep -qE '^[[:space:]]*#[[:space:]]*@failure-mode:[[:space:]]*dispatch-error'
  body_grep | grep -qE '^[[:space:]]*#[[:space:]]*@failure-mode:[[:space:]]*concurrent-edit'
  body_grep | grep -qE '^[[:space:]]*#[[:space:]]*@failure-mode:[[:space:]]*save-failure'
}

@test "seed/cmd_artifact_write: side-effect markers exist in body" {
  set -e
  body_grep() {
    awk '/^cmd_artifact_write\(\)/{f=1} f{print} /^\}/&&f{f=0}' "$TARGET"
  }
  body_grep | grep -qE '^[[:space:]]*#[[:space:]]*@side-effect:[[:space:]]*writes-local-doc'
  body_grep | grep -qE '^[[:space:]]*#[[:space:]]*@side-effect:[[:space:]]*upserts-linear-document'
  body_grep | grep -qE '^[[:space:]]*#[[:space:]]*@side-effect:[[:space:]]*sets-doc-cache-updated-at'
}
