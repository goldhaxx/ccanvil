#!/usr/bin/env bats

# BTS-497 telemetry hooks.
source "$BATS_TEST_DIRNAME/_helpers/telemetry.bash"
setup_file()    { telemetry_setup_file; }
teardown_file() { telemetry_teardown_file; }
# Tests for docs-check.sh validate — Work:-based alignment + session-kind
# exclusion + legacy feature_id grandfather.
# BTS-130 (work-identity) — Phase 3: validator.

SCRIPT="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/docs-check.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  DOCS=$(mktemp -d)
  telemetry_setup
}

teardown() {
  telemetry_teardown
  rm -rf "$DOCS"
}

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

_write_spec() {
  local fid="$1" work="${2:-}"
  {
    echo "# Feature: Test"
    echo ""
    echo "> Feature: $fid"
    [[ -n "$work" ]] && echo "> Work: $work"
    echo "> Created: 1776973070"
    echo "> Status: In Progress"
    echo ""
    echo "## Summary"
    echo "Body."
  } > "$DOCS/spec.md"
}

_write_plan() {
  local fid="$1" work="${2:-}"
  {
    echo "# Implementation Plan: Test"
    echo ""
    echo "> Feature: $fid"
    [[ -n "$work" ]] && echo "> Work: $work"
    echo "> Created: 1776973070"
    echo "> Spec hash: $(bash "$SCRIPT" status "$DOCS" | jq -r '.spec.content_hash // "abc"')"
    echo ""
    echo "## Objective"
    echo "Body."
  } > "$DOCS/plan.md"
}

_write_stasis() {
  local fid="$1" work="${2:-}" kind="${3:-}"
  {
    echo "# Stasis"
    echo ""
    echo "> Feature: $fid"
    [[ -n "$work" ]] && echo "> Work: $work"
    [[ -n "$kind" ]] && echo "> Kind: $kind"
    local plan_hash
    plan_hash=$(bash "$SCRIPT" status "$DOCS" | jq -r '.plan.content_hash // "xyz"')
    echo "> Last updated: 1776971680"
    echo "> Plan hash: $plan_hash"
    echo ""
    echo "## Accomplished"
    echo "Body."
    echo ""
    echo "## Determinism Review"
    echo "No candidates this session."
  } > "$DOCS/stasis.md"
}

# ===========================================================================
# Step 8 — Work: equality alignment (AC-7, AC-8)
# ===========================================================================

@test "BTS-130 AC-7: spec+plan+stasis with matching Work: → aligned" {
  _write_spec "bts-130-feat" "linear:BTS-130"
  _write_plan "bts-130-feat" "linear:BTS-130"
  _write_stasis "bts-130-feat" "linear:BTS-130" "feature"
  run bash "$SCRIPT" validate "$DOCS"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.result == "aligned"'
}

@test "BTS-130 AC-8: differing Work: values across docs → mismatched" {
  _write_spec "bts-130-feat" "linear:BTS-130"
  _write_plan "bts-130-feat" "linear:BTS-999"
  _write_stasis "bts-130-feat" "linear:BTS-130" "feature"
  run bash "$SCRIPT" validate "$DOCS"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.result == "mismatched"'
}

# ===========================================================================
# Step 9 — Session-kind stasis excluded from feature alignment (BTS-120 fix)
# AC-9
# ===========================================================================

@test "BTS-130 AC-9 (BTS-120 fix): session-kind stasis does not trip mismatch" {
  _write_spec "bts-130-feat" "linear:BTS-130"
  _write_plan "bts-130-feat" "linear:BTS-130"
  # A lingering session-boundary stasis that rode into the feature branch.
  # No Work:, Kind: session, mismatched feature_id — must be skipped by validator.
  _write_stasis "session-2026-04-23-prior-ship" "" "session"
  run bash "$SCRIPT" validate "$DOCS"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.result == "aligned"'
}

@test "BTS-130 step 9: feature-kind stasis with mismatched Work: still trips" {
  _write_spec "bts-130-feat" "linear:BTS-130"
  _write_plan "bts-130-feat" "linear:BTS-130"
  _write_stasis "other-feat" "linear:BTS-999" "feature"
  run bash "$SCRIPT" validate "$DOCS"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.result == "mismatched"'
}

# ===========================================================================
# Step 10 — Legacy grandfather: fallback to feature_id when any doc lacks Work:
# AC-10
# ===========================================================================

@test "BTS-130 AC-10: legacy specs (no Work:) with matching feature_ids → aligned" {
  _write_spec "legacy-feat" ""
  _write_plan "legacy-feat" ""
  _write_stasis "legacy-feat" "" "feature"
  run bash "$SCRIPT" validate "$DOCS"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.result == "aligned"'
}

@test "BTS-130 AC-10: legacy specs (no Work:) with differing feature_ids → mismatched" {
  _write_spec "legacy-a" ""
  _write_plan "legacy-b" ""
  _write_stasis "legacy-a" "" "feature"
  run bash "$SCRIPT" validate "$DOCS"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.result == "mismatched"'
}

@test "BTS-130 AC-10: partial migration (spec has Work:, plan doesn't) → feature_id fallback" {
  _write_spec "bts-130-feat" "linear:BTS-130"
  _write_plan "bts-130-feat" ""
  _write_stasis "bts-130-feat" "" "feature"
  run bash "$SCRIPT" validate "$DOCS"
  [ "$status" -eq 0 ]
  # Not all docs carry Work: → fall back to feature_id alignment → aligned
  echo "$output" | jq -e '.result == "aligned"'
}
