#!/usr/bin/env bats
# BTS-204 — drift-guards for SSOT-Linear: routing of spec/plan/stasis to Linear Documents
# (vs Issue.description) via provider-driven configuration. Local-routed nodes preserve
# file-based flow unchanged.

bats_require_minimum_version 1.5.0

LQ="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/linear-query.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  unset LINEAR_API_KEY
  unset LINEAR_QUERY_ENDPOINT
}

# =========================================================================
# AC-4 / Step 1: resolve-document-id — deterministic UUID derivation
# =========================================================================

@test "BTS-204 Step 1: resolve-document-id returns a valid UUID-format string" {
  run bash "$LQ" resolve-document-id --kind spec --ticket BTS-204
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]
}

@test "BTS-204 Step 1: resolve-document-id is deterministic across invocations" {
  run bash "$LQ" resolve-document-id --kind spec --ticket BTS-204
  first="$output"
  run bash "$LQ" resolve-document-id --kind spec --ticket BTS-204
  [ "$output" = "$first" ]
}

@test "BTS-204 Step 1: resolve-document-id differs per kind for same ticket" {
  run bash "$LQ" resolve-document-id --kind spec --ticket BTS-204
  spec_id="$output"
  run bash "$LQ" resolve-document-id --kind plan --ticket BTS-204
  plan_id="$output"
  [ "$spec_id" != "$plan_id" ]
}

@test "BTS-204 Step 1: resolve-document-id differs per ticket for same kind" {
  run bash "$LQ" resolve-document-id --kind spec --ticket BTS-204
  a="$output"
  run bash "$LQ" resolve-document-id --kind spec --ticket BTS-205
  b="$output"
  [ "$a" != "$b" ]
}

@test "BTS-204 Step 1: resolve-document-id accepts all four kinds" {
  for kind in spec plan feature-stasis session-stasis; do
    run bash "$LQ" resolve-document-id --kind "$kind" --ticket BTS-204
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]
  done
}

@test "BTS-204 Step 1: resolve-document-id rejects unknown kind with exit 2" {
  run --separate-stderr bash "$LQ" resolve-document-id --kind bogus --ticket BTS-204
  [ "$status" -eq 2 ]
  [[ "$stderr" =~ "Unknown kind" ]] || [[ "$stderr" =~ "kind" ]]
}

@test "BTS-204 Step 1: resolve-document-id requires --kind and --ticket" {
  run --separate-stderr bash "$LQ" resolve-document-id --kind spec
  [ "$status" -eq 2 ]
  run --separate-stderr bash "$LQ" resolve-document-id --ticket BTS-204
  [ "$status" -eq 2 ]
}
