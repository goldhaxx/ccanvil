#!/usr/bin/env bats
# BTS-228 — drift-guards for linear-query.sh create-relation primitive +
# the save-issue --duplicate-of two-step flow.

bats_require_minimum_version 1.5.0

# BTS-497 telemetry hooks.
source "$BATS_TEST_DIRNAME/_helpers/telemetry.bash"
setup_file()    { telemetry_setup_file; }
teardown_file() { telemetry_teardown_file; }
teardown()      { telemetry_teardown; }

LQ="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/linear-query.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  unset LINEAR_QUERY_ENDPOINT
  # Set a dummy API key so the validation paths run before _require_api_key
  # short-circuits. Validation tests check input rejection BEFORE GraphQL.
  export LINEAR_API_KEY="test_dummy_key_for_validation_paths"
  telemetry_setup
}

# =========================================================================
# AC-4: --type validation
# =========================================================================

@test "BTS-228 AC-4: create-relation rejects missing --type" {
  run bash "$LQ" create-relation --issue aaa --related bbb
  [ "$status" -eq 2 ]
  [[ "$output" =~ "--type required" ]]
}

@test "BTS-228 AC-4: create-relation rejects unknown --type" {
  run bash "$LQ" create-relation --type bogus --issue aaa --related bbb
  [ "$status" -eq 2 ]
  [[ "$output" =~ "unknown --type" ]]
  [[ "$output" =~ "duplicate" ]]
  [[ "$output" =~ "blocks" ]]
  [[ "$output" =~ "related" ]]
}

@test "BTS-228 AC-4: create-relation accepts type=duplicate at validation" {
  # We expect this to pass validation but fail at the GraphQL layer (dummy
  # key). Exit code from a GraphQL failure is 3 (per existing convention).
  run bash "$LQ" create-relation --type duplicate --issue aaa --related bbb
  [ "$status" -ne 2 ]   # NOT a validation error
}

@test "BTS-228 AC-4: create-relation accepts type=blocks at validation" {
  run bash "$LQ" create-relation --type blocks --issue aaa --related bbb
  [ "$status" -ne 2 ]
}

@test "BTS-228 AC-4: create-relation accepts type=related at validation" {
  run bash "$LQ" create-relation --type related --issue aaa --related bbb
  [ "$status" -ne 2 ]
}

# =========================================================================
# AC-5: --issue / --related validation
# =========================================================================

@test "BTS-228 AC-5: create-relation rejects missing --issue" {
  run bash "$LQ" create-relation --type duplicate --related bbb
  [ "$status" -eq 2 ]
  [[ "$output" =~ "--issue required" ]]
}

@test "BTS-228 AC-5: create-relation rejects missing --related" {
  run bash "$LQ" create-relation --type duplicate --issue aaa
  [ "$status" -eq 2 ]
  [[ "$output" =~ "--related required" ]]
}

@test "BTS-228 AC-5: create-relation rejects unknown flag" {
  run bash "$LQ" create-relation --type duplicate --issue aaa --related bbb --bogus xyz
  [ "$status" -eq 2 ]
  [[ "$output" =~ "unknown flag" ]]
}

# =========================================================================
# Substrate state lock — fix not regressed
# =========================================================================

@test "BTS-228 lock: cmd_save_issue does NOT append duplicateOf to IssueUpdateInput" {
  # Static check: the broken pattern from before BTS-228 must not return.
  set -e
  ! grep -E "input=\\\$\\(printf.*'\\. \\+ \\{duplicateOf:" "$LQ"
}

@test "BTS-228 lock: cmd_create_relation function exists in linear-query.sh" {
  set -e
  grep -q '^cmd_create_relation()' "$LQ"
}

@test "BTS-228 lock: dispatcher routes 'create-relation' subcommand" {
  set -e
  grep -qE 'create-relation\)\s+cmd_create_relation' "$LQ"
}
