#!/usr/bin/env bats
# Tests for scripts/docs-check.sh
#
# Each test creates isolated temp directories with mock docs.
# Metadata lives in blockquote lines (> Key: value) after the heading.

SCRIPT="$BATS_TEST_DIRNAME/../scripts/docs-check.sh"

# ---------------------------------------------------------------------------
# Fixtures: create mock docs directory
# ---------------------------------------------------------------------------

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  DOCS=$(mktemp -d)
}

teardown() {
  rm -rf "$DOCS"
}

# ---------------------------------------------------------------------------
# Helper: create a spec.md with lifecycle metadata
# ---------------------------------------------------------------------------
create_spec() {
  local feature_id="${1:-my-feature}"
  local created="${2:-1742860800}"
  local status="${3:-In Progress}"
  cat > "$DOCS/spec.md" <<EOF
# Feature: Test Feature

> Feature: ${feature_id}
> Created: ${created}
> Status: ${status}

## Summary

This is the spec body content.

## Acceptance Criteria

- [ ] AC-1: Something testable
EOF
}

# ---------------------------------------------------------------------------
# Helper: create a plan.md with lifecycle metadata
# ---------------------------------------------------------------------------
create_plan() {
  local feature_id="${1:-my-feature}"
  local created="${2:-1742860900}"
  local spec_hash="${3:-abcd1234}"
  cat > "$DOCS/plan.md" <<EOF
# Implementation Plan: Test Feature

> Feature: ${feature_id}
> Created: ${created}
> Spec hash: ${spec_hash}

## Objective

Implement the test feature.

## Sequence

### Step 1: Do the thing
EOF
}

# ---------------------------------------------------------------------------
# Helper: create a checkpoint.md with lifecycle metadata
# ---------------------------------------------------------------------------
create_checkpoint() {
  local feature_id="${1:-my-feature}"
  local updated="${2:-1742861000}"
  local plan_hash="${3:-efgh5678}"
  cat > "$DOCS/checkpoint.md" <<EOF
# Checkpoint

> Feature: ${feature_id}
> Last updated: ${updated}
> Plan hash: ${plan_hash}

## Accomplished

- Did something.

## Next Steps

- Do more.
EOF
}

# ===========================================================================
# Step 1: status — metadata extraction
# ===========================================================================

@test "status: extracts feature_id and status from spec.md" {
  create_spec "my-feature" "1742860800" "In Progress"
  run bash "$SCRIPT" status "$DOCS"
  [ "$status" -eq 0 ]

  # Parse spec entry from JSON output
  spec_feature=$(echo "$output" | jq -r '.spec.feature_id')
  spec_status=$(echo "$output" | jq -r '.spec.status')
  spec_created=$(echo "$output" | jq -r '.spec.created')

  [ "$spec_feature" = "my-feature" ]
  [ "$spec_status" = "In Progress" ]
  [ "$spec_created" = "1742860800" ]
}

@test "status: extracts feature_id and spec_hash from plan.md" {
  create_plan "my-feature" "1742860900" "abcd1234"
  run bash "$SCRIPT" status "$DOCS"
  [ "$status" -eq 0 ]

  plan_feature=$(echo "$output" | jq -r '.plan.feature_id')
  plan_created=$(echo "$output" | jq -r '.plan.created')
  plan_spec_hash=$(echo "$output" | jq -r '.plan.spec_hash')

  [ "$plan_feature" = "my-feature" ]
  [ "$plan_created" = "1742860900" ]
  [ "$plan_spec_hash" = "abcd1234" ]
}

@test "status: extracts feature_id and plan_hash from checkpoint.md" {
  create_checkpoint "my-feature" "1742861000" "efgh5678"
  run bash "$SCRIPT" status "$DOCS"
  [ "$status" -eq 0 ]

  cp_feature=$(echo "$output" | jq -r '.checkpoint.feature_id')
  cp_updated=$(echo "$output" | jq -r '.checkpoint.last_updated')
  cp_plan_hash=$(echo "$output" | jq -r '.checkpoint.plan_hash')

  [ "$cp_feature" = "my-feature" ]
  [ "$cp_updated" = "1742861000" ]
  [ "$cp_plan_hash" = "efgh5678" ]
}

@test "status: includes computed content_hash for each document" {
  create_spec "my-feature" "1742860800" "In Progress"
  run bash "$SCRIPT" status "$DOCS"
  [ "$status" -eq 0 ]

  content_hash=$(echo "$output" | jq -r '.spec.content_hash')
  # Hash should be 8 hex chars (sha256 truncated)
  [[ "$content_hash" =~ ^[0-9a-f]{8}$ ]]
}

@test "status: reports missing documents without error" {
  # Empty docs dir — no files at all
  run bash "$SCRIPT" status "$DOCS"
  [ "$status" -eq 0 ]

  spec_exists=$(echo "$output" | jq -r '.spec.exists')
  plan_exists=$(echo "$output" | jq -r '.plan.exists')
  cp_exists=$(echo "$output" | jq -r '.checkpoint.exists')

  [ "$spec_exists" = "false" ]
  [ "$plan_exists" = "false" ]
  [ "$cp_exists" = "false" ]
}

@test "status: reports unlinked when doc exists but has no metadata" {
  # Spec with no blockquote metadata
  cat > "$DOCS/spec.md" <<'EOF'
# Some Feature

## Summary

No metadata blockquote here.
EOF

  run bash "$SCRIPT" status "$DOCS"
  [ "$status" -eq 0 ]

  spec_exists=$(echo "$output" | jq -r '.spec.exists')
  spec_feature=$(echo "$output" | jq -r '.spec.feature_id')

  [ "$spec_exists" = "true" ]
  [ "$spec_feature" = "null" ]
}

@test "status: all three docs together produce complete JSON" {
  create_spec "my-feature" "1742860800" "In Progress"
  create_plan "my-feature" "1742860900" "abcd1234"
  create_checkpoint "my-feature" "1742861000" "efgh5678"

  run bash "$SCRIPT" status "$DOCS"
  [ "$status" -eq 0 ]

  # All three should exist and have feature_id
  spec_f=$(echo "$output" | jq -r '.spec.feature_id')
  plan_f=$(echo "$output" | jq -r '.plan.feature_id')
  cp_f=$(echo "$output" | jq -r '.checkpoint.feature_id')

  [ "$spec_f" = "my-feature" ]
  [ "$plan_f" = "my-feature" ]
  [ "$cp_f" = "my-feature" ]

  # All three should have content_hash
  spec_h=$(echo "$output" | jq -r '.spec.content_hash')
  plan_h=$(echo "$output" | jq -r '.plan.content_hash')
  cp_h=$(echo "$output" | jq -r '.checkpoint.content_hash')

  [[ "$spec_h" =~ ^[0-9a-f]{8}$ ]]
  [[ "$plan_h" =~ ^[0-9a-f]{8}$ ]]
  [[ "$cp_h" =~ ^[0-9a-f]{8}$ ]]
}

# ===========================================================================
# Step 2: content hashing — metadata vs body isolation
# ===========================================================================

@test "hash: changing metadata does not change content_hash" {
  create_spec "my-feature" "1742860800" "In Progress"
  run bash "$SCRIPT" status "$DOCS"
  hash_before=$(echo "$output" | jq -r '.spec.content_hash')

  # Change metadata only (status field)
  create_spec "my-feature" "1742860800" "Complete"
  run bash "$SCRIPT" status "$DOCS"
  hash_after=$(echo "$output" | jq -r '.spec.content_hash')

  [ "$hash_before" = "$hash_after" ]
}

@test "hash: changing body content changes content_hash" {
  create_spec "my-feature" "1742860800" "In Progress"
  run bash "$SCRIPT" status "$DOCS"
  hash_before=$(echo "$output" | jq -r '.spec.content_hash')

  # Append to body
  echo "## New Section" >> "$DOCS/spec.md"
  echo "Extra content that changes the hash." >> "$DOCS/spec.md"

  run bash "$SCRIPT" status "$DOCS"
  hash_after=$(echo "$output" | jq -r '.spec.content_hash')

  [ "$hash_before" != "$hash_after" ]
}

@test "hash: changing feature_id does not change content_hash" {
  create_spec "feature-a" "1742860800" "In Progress"
  run bash "$SCRIPT" status "$DOCS"
  hash_a=$(echo "$output" | jq -r '.spec.content_hash')

  create_spec "feature-b" "1742860800" "In Progress"
  run bash "$SCRIPT" status "$DOCS"
  hash_b=$(echo "$output" | jq -r '.spec.content_hash')

  [ "$hash_a" = "$hash_b" ]
}

@test "hash: changing timestamp does not change content_hash" {
  create_plan "my-feature" "1742860900" "abcd1234"
  run bash "$SCRIPT" status "$DOCS"
  hash_before=$(echo "$output" | jq -r '.plan.content_hash')

  create_plan "my-feature" "9999999999" "abcd1234"
  run bash "$SCRIPT" status "$DOCS"
  hash_after=$(echo "$output" | jq -r '.plan.content_hash')

  [ "$hash_before" = "$hash_after" ]
}

@test "hash: identical body across doc types produces same hash" {
  # Create spec and plan with identical body content
  cat > "$DOCS/spec.md" <<'EOF'
# Feature A

> Feature: test
> Created: 100

## Body

Same content here.
EOF

  cat > "$DOCS/plan.md" <<'EOF'
# Plan A

> Feature: test
> Created: 200
> Spec hash: abc

## Body

Same content here.
EOF

  run bash "$SCRIPT" status "$DOCS"
  spec_hash=$(echo "$output" | jq -r '.spec.content_hash')
  plan_hash=$(echo "$output" | jq -r '.plan.content_hash')

  [ "$spec_hash" = "$plan_hash" ]
}
