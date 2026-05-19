#!/usr/bin/env bats

# BTS-497 telemetry hooks.
source "$BATS_TEST_DIRNAME/_helpers/telemetry.bash"
setup_file()    { telemetry_setup_file; }
teardown_file() { telemetry_teardown_file; }
teardown()      { telemetry_teardown; }
# BTS-265: cmd_validate_spec — Layer 1 spec structural validation.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/.ccanvil/scripts/docs-check.sh"
  FIXTURE_DIR="$REPO_ROOT/hub/tests/fixtures/specs"
  telemetry_setup
}

# AC-7: unknown feature → exit 2 with stderr error.
@test "validate-spec: unknown feature exits 2 with spec-not-found stderr" {
  run bash "$SCRIPT" validate-spec --feature nonexistent-$$-feature --project-dir "$REPO_ROOT"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "spec not found" ]]
}

# Test fixtures live under hub/tests/fixtures/specs/. We stage each into a tmpdir's
# docs/specs/<id>.md so cmd_validate_spec finds it via the standard path.
_stage_fixture() {
  local fixture="$1"; local feature="$2"; local target="$BATS_TEST_TMPDIR/$feature"
  mkdir -p "$target/docs/specs"
  cp "$FIXTURE_DIR/$fixture" "$target/docs/specs/$feature.md"
  echo "$target"
}

# AC-2: ac_count == 0 → status drift, finding "no-acceptance-criteria".
@test "validate-spec: zero acceptance criteria → drift" {
  set -e
  staged=$(_stage_fixture no-acs.md no-acs)
  run bash "$SCRIPT" validate-spec --feature no-acs --project-dir "$staged"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.status == "drift"'
  echo "$output" | jq -e '.coverage.ac_count == 0'
  echo "$output" | jq -e '.findings | index("no-acceptance-criteria") != null'
}

# AC-4: error/edge criterion missing → drift.
@test "validate-spec: missing error criterion → drift" {
  set -e
  staged=$(_stage_fixture no-error-ac.md no-error-ac)
  run bash "$SCRIPT" validate-spec --feature no-error-ac --project-dir "$staged"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.status == "drift"'
  echo "$output" | jq -e '.coverage.error_criterion_count == 0'
  echo "$output" | jq -e '.findings | index("missing-error-criterion") != null'
}

# AC-3: ac_count >= 4 with no GWT → drift.
@test "validate-spec: 4+ ACs with no GWT → drift" {
  set -e
  staged=$(_stage_fixture no-gwt-when-required.md no-gwt-when-required)
  run bash "$SCRIPT" validate-spec --feature no-gwt-when-required --project-dir "$staged"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.coverage.ac_count >= 4'
  echo "$output" | jq -e '.coverage.gwt_count == 0'
  echo "$output" | jq -e '.findings | index("missing-given-when-then") != null'
}

# AC-5: file ref that doesn't exist and isn't New → drift with missing_file_refs entry.
@test "validate-spec: missing file ref (non-New) → drift" {
  set -e
  staged=$(_stage_fixture missing-file-ref.md missing-file-ref)
  run bash "$SCRIPT" validate-spec --feature missing-file-ref --project-dir "$staged"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.status == "drift"'
  echo "$output" | jq -e '.missing_file_refs | length >= 1'
  echo "$output" | jq -e '[.missing_file_refs[].path] | index("nonexistent/path/to/file.ts") != null'
}

# AC-6: well-formed small spec → exit 0, status ok.
@test "validate-spec: happy path (small spec, error AC, no GWT needed) → ok" {
  set -e
  staged=$(_stage_fixture happy-path.md happy-path)
  run bash "$SCRIPT" validate-spec --feature happy-path --project-dir "$staged"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.status == "ok"'
  echo "$output" | jq -e '.missing_file_refs == []'
  echo "$output" | jq -e '.coverage.error_criterion_count >= 1'
}
