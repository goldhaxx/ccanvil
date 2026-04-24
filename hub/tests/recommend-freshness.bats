#!/usr/bin/env bats
# BTS-113 — recommend distinguishes pre-compact (suggest /compact) from
# post-compact (suggest forward action) via .ccanvil/state/last-compact-ts
# marker written by a PreCompact hook.

bats_require_minimum_version 1.5.0

DOCS="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/docs-check.sh"
HOOK="$BATS_TEST_DIRNAME/../../.claude/hooks/post-compact-marker.sh"
SETTINGS="$BATS_TEST_DIRNAME/../../.claude/settings.json"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  PROJECT=$(mktemp -d)
  mkdir -p "$PROJECT/docs/specs"
  mkdir -p "$PROJECT/.ccanvil"
}

teardown() {
  rm -rf "$PROJECT"
}

# Seed a stasis file with the given last_updated epoch. No active spec/plan.
_seed_stasis() {
  local last_updated="$1"
  cat > "$PROJECT/docs/stasis.md" <<MD
# Stasis

> Feature: session-test
> Kind: session
> Last updated: $last_updated

## Accomplished
Stub.

## Current State
- Branch: main

## Determinism Review
- No candidates this session.
MD
}

# Write the compact marker with the given epoch.
_seed_marker() {
  local ts="$1"
  mkdir -p "$PROJECT/.ccanvil/state"
  echo "$ts" > "$PROJECT/.ccanvil/state/last-compact-ts"
}

# Seed a mock ideas log for idea-count testing.
_seed_ideas_triage() {
  local count="$1"
  : > "$PROJECT/.ccanvil/ideas.log"
  local i
  for (( i=0; i < count; i++ )); do
    printf '{"uid":"idea-%d","title":"stub","body":"stub","status":"triage","ts":%d}\n' "$i" "$(date +%s)" >> "$PROJECT/.ccanvil/ideas.log"
  done
}

# ----------------------------------------------------------------------------
# Step 1: PreCompact hook writes the marker
# ----------------------------------------------------------------------------

@test "BTS-113: PreCompact hook exists and is executable" {
  [ -x "$HOOK" ]
}

@test "BTS-113: PreCompact hook writes epoch to .ccanvil/state/last-compact-ts" {
  set -e
  cd "$PROJECT"
  bash "$HOOK"
  [ -f "$PROJECT/.ccanvil/state/last-compact-ts" ]
  local ts now
  ts=$(cat "$PROJECT/.ccanvil/state/last-compact-ts")
  now=$(date +%s)
  [ "$ts" -gt 0 ]
  [ "$ts" -le "$now" ]
}

# ----------------------------------------------------------------------------
# Step 2: settings.json registers the hook under PreCompact
# ----------------------------------------------------------------------------

@test "BTS-113: .claude/settings.json registers PreCompact hook referencing post-compact-marker.sh" {
  set -e
  jq -e '.hooks.PreCompact' "$SETTINGS" > /dev/null
  local hook_refs
  hook_refs=$(jq -r '.hooks.PreCompact[]?.hooks[]?.command // empty' "$SETTINGS")
  [[ "$hook_refs" =~ post-compact-marker.sh ]]
}

# ----------------------------------------------------------------------------
# Step 3: cmd_recommend reads marker and branches
# ----------------------------------------------------------------------------

@test "BTS-113 AC-2/AC-6: stasis exists, NO marker → recommend /compact (fallback)" {
  set -e
  _seed_stasis "$(date +%s)"
  run bash "$DOCS" recommend "$PROJECT/docs"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.next_action | contains("/compact")'
}

@test "BTS-113 AC-1: marker > stasis.last_updated → recommend forward action (not /compact)" {
  set -e
  local stasis_ts=1700000000
  local marker_ts=1700000100
  _seed_stasis "$stasis_ts"
  _seed_marker "$marker_ts"
  run bash "$DOCS" recommend "$PROJECT/docs"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.next_action | contains("/compact") | not'
}

@test "BTS-113 AC-7: marker < stasis.last_updated → recommend /compact (stasis written after last compact)" {
  set -e
  local marker_ts=1700000000
  local stasis_ts=1700000100
  _seed_stasis "$stasis_ts"
  _seed_marker "$marker_ts"
  run bash "$DOCS" recommend "$PROJECT/docs"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.next_action | contains("/compact")'
}

@test "BTS-113: marker == stasis.last_updated → recommend forward action (ties go to post-compact)" {
  set -e
  local ts=1700000000
  _seed_stasis "$ts"
  _seed_marker "$ts"
  run bash "$DOCS" recommend "$PROJECT/docs"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.next_action | contains("/compact") | not'
}

# ----------------------------------------------------------------------------
# Step 4: Forward-action hierarchy
# ----------------------------------------------------------------------------

@test "BTS-113 AC-5: fresh post-compact with triage ideas → recommend /idea triage" {
  set -e
  _seed_stasis 1700000000
  _seed_marker 1700000100
  _seed_ideas_triage 3
  run bash "$DOCS" recommend "$PROJECT/docs"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.next_action | contains("/idea triage")'
}

@test "BTS-113 AC-5: fresh post-compact with no ideas → recommend /radar" {
  set -e
  _seed_stasis 1700000000
  _seed_marker 1700000100
  run bash "$DOCS" recommend "$PROJECT/docs"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.next_action | contains("/radar")'
}

# ----------------------------------------------------------------------------
# Step 6: status surfaces last_compact_ts
# ----------------------------------------------------------------------------

@test "BTS-113: docs-check.sh status includes last_compact_ts (epoch or null)" {
  set -e
  _seed_marker 1700001234
  run bash "$DOCS" status "$PROJECT/docs"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.last_compact_ts == 1700001234'
}

@test "BTS-113: docs-check.sh status last_compact_ts is null when marker absent" {
  set -e
  # No marker seeded.
  run bash "$DOCS" status "$PROJECT/docs"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.last_compact_ts == null'
}

# ----------------------------------------------------------------------------
# AC-9 + WARN-fix: marker file with trailing whitespace is still valid
# ----------------------------------------------------------------------------

@test "BTS-113 AC-9: .gitignore excludes .ccanvil/state/" {
  local gitignore="$BATS_TEST_DIRNAME/../../.gitignore"
  grep -q '\.ccanvil/state/' "$gitignore"
}

@test "BTS-113 WARN-fix: marker file with trailing whitespace still parses as integer" {
  set -e
  _seed_stasis 1700000000
  mkdir -p "$PROJECT/.ccanvil/state"
  # Write marker with trailing newline + trailing whitespace (simulates a
  # double-write race or a hand-edited file).
  printf '1700000100\n   \n' > "$PROJECT/.ccanvil/state/last-compact-ts"
  run bash "$DOCS" recommend "$PROJECT/docs"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.next_action | contains("/compact") | not'
}
