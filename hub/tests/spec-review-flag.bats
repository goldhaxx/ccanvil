#!/usr/bin/env bats
# BTS-266: /spec --review critic-mode dispatch shape.
#
# Bats coverage is intentionally narrow — the deterministic prefix is testable
# (validate-spec invocation against existing/missing spec); agent spawn behavior
# is OoS per spec AC-7.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/.ccanvil/scripts/docs-check.sh"
  FIXTURE_DIR="$REPO_ROOT/hub/tests/fixtures/specs"
}

# AC-4: --review on missing spec surfaces the validate-spec error.
@test "spec-review: missing feature exits 2 with spec-not-found stderr" {
  run bash "$SCRIPT" validate-spec --feature totally-nonexistent-$$-feature --project-dir "$REPO_ROOT"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "spec not found" ]]
}

# AC-1 prefix: --review on a happy-path spec runs validate-spec and emits the JSON envelope.
@test "spec-review: validate-spec runs first and emits envelope on existing spec" {
  set -e
  staged="$BATS_TEST_TMPDIR/critic-existing"
  mkdir -p "$staged/docs/specs"
  cp "$FIXTURE_DIR/happy-path.md" "$staged/docs/specs/happy-path.md"
  run bash "$SCRIPT" validate-spec --feature happy-path --project-dir "$staged"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.coverage | has("ac_count") and has("gwt_count") and has("error_criterion_count") and has("file_refs_resolved")'
  echo "$output" | jq -e '.findings | type == "array"'
  echo "$output" | jq -e '.status == "ok" or .status == "drift"'
}

# AC-3 (drift envelope passthrough): --review on a drifty spec still emits the envelope at exit 2;
# critic mode consumes it as input rather than blocking.
@test "spec-review: drifty spec emits envelope at exit 2 (critic-mode-consumable)" {
  set -e
  staged="$BATS_TEST_TMPDIR/critic-drifty"
  mkdir -p "$staged/docs/specs"
  cp "$FIXTURE_DIR/no-error-ac.md" "$staged/docs/specs/no-error-ac.md"
  run bash "$SCRIPT" validate-spec --feature no-error-ac --project-dir "$staged"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.status == "drift"'
  echo "$output" | jq -e '.findings | length >= 1'
}
