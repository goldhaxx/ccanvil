#!/usr/bin/env bats

# BTS-497 telemetry hooks.
source "$BATS_TEST_DIRNAME/_helpers/telemetry.bash"
setup_file()    { telemetry_setup_file; }
teardown_file() { telemetry_teardown_file; }
teardown()      { telemetry_teardown; }
# BTS-268: cmd_diff_vs_manifest substrate — deterministic Layer 3 ramp.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/.ccanvil/scripts/module-manifest.sh"
  telemetry_setup
}

# AC-7: missing diff file → exit 2 with stderr error.
@test "diff-vs-manifest: missing --diff file exits 2 with diff-file-not-found stderr" {
  run bash "$SCRIPT" diff-vs-manifest --diff /nonexistent/path/$$.diff
  [ "$status" -eq 2 ]
  [[ "$output" =~ "diff file not found" ]]
}

# AC-6: clean diff (touches only docs / non-manifested paths) → empty drift envelope.
@test "diff-vs-manifest: clean diff emits empty drift envelope (exit 0)" {
  set -e
  run bash "$SCRIPT" diff-vs-manifest --diff "$REPO_ROOT/hub/tests/fixtures/manifest/diffs/clean.diff"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.drift == []'
  echo "$output" | jq -e '.status == "ok"'
}

# AC-5: new-side-effect-not-declared. Diff adds `# @side-effect: writes-undeclared-marker`
# inside cmd_query's body, but `writes-undeclared-marker` not in declared side-effect array.
@test "diff-vs-manifest: new @side-effect marker → new-side-effect-not-declared drift" {
  set -e
  run bash "$SCRIPT" diff-vs-manifest --diff "$REPO_ROOT/hub/tests/fixtures/manifest/diffs/new-side-effect.diff"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.status == "drift"'
  echo "$output" | jq -e '[.drift[] | select(.drift_type == "new-side-effect-not-declared" and .id == "cmd_query" and .value == "writes-undeclared-marker")] | length >= 1'
}

# AC-4: new-exit-path-not-declared. Diff adds `+ return 7` inside cmd_query's body
# but no failure-mode entry has exit=7 → drift entry.
@test "diff-vs-manifest: new exit code in body → new-exit-path-not-declared drift" {
  set -e
  run bash "$SCRIPT" diff-vs-manifest --diff "$REPO_ROOT/hub/tests/fixtures/manifest/diffs/new-exit-path.diff"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.status == "drift"'
  echo "$output" | jq -e '[.drift[] | select(.drift_type == "new-exit-path-not-declared" and .id == "cmd_query" and .value == "7")] | length >= 1'
}

# AC-3: new-depends-on-not-declared. Diff adds `bash linear-query.sh ...` inside
# cmd_query's body, but linear-query.sh is NOT in cmd_query's declared depends-on.
@test "diff-vs-manifest: new depends-on in body → new-depends-on-not-declared drift" {
  set -e
  run bash "$SCRIPT" diff-vs-manifest --diff "$REPO_ROOT/hub/tests/fixtures/manifest/diffs/new-depends-on.diff"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.status == "drift"'
  echo "$output" | jq -e '[.drift[] | select(.drift_type == "new-depends-on-not-declared" and .id == "cmd_query" and .value == "linear-query.sh")] | length >= 1'
}

# AC-2: new-caller-not-declared. New skill file invokes cmd_extract; primitive's
# manifest caller list does NOT include the new skill path → drift entry.
@test "diff-vs-manifest: new caller in added file → new-caller-not-declared drift" {
  set -e
  run bash "$SCRIPT" diff-vs-manifest --diff "$REPO_ROOT/hub/tests/fixtures/manifest/diffs/new-caller.diff"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.status == "drift"'
  echo "$output" | jq -e '.drift | length >= 1'
  echo "$output" | jq -e '[.drift[] | select(.drift_type == "new-caller-not-declared")] | length >= 1'
  # Specifically: the new skill path appears as the value in some new-caller drift entry.
  echo "$output" | jq -e '[.drift[] | select(.drift_type == "new-caller-not-declared" and .value == ".claude/skills/test-new-caller/SKILL.md")] | length >= 1'
}

# BTS-667 AC-1/AC-2: a new function defined INSIDE a hunk whose xfuncname header
# points to a DIFFERENT existing function (cmd_extract). The new function's body
# marker must attribute to the new function (cmd_query), not the surrounding one.
@test "BTS-667 AC-1: new-fn body marker does NOT attribute to the surrounding fn (cmd_extract)" {
  set -e
  run bash "$SCRIPT" diff-vs-manifest --diff "$REPO_ROOT/hub/tests/fixtures/manifest/diffs/new-fn-reattribution-side-effect.diff"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '[.drift[] | select(.drift_type == "new-side-effect-not-declared" and .id == "cmd_extract")] | length == 0'
}

@test "BTS-667 AC-2: new-fn body marker re-attributes to the new fn (cmd_query)" {
  set -e
  run bash "$SCRIPT" diff-vs-manifest --diff "$REPO_ROOT/hub/tests/fixtures/manifest/diffs/new-fn-reattribution-side-effect.diff"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '[.drift[] | select(.drift_type == "new-side-effect-not-declared" and .id == "cmd_query" and .value == "writes-undeclared-marker")] | length >= 1'
}

# BTS-667 AC-3: parity — the same re-attribution applies to the other two
# hunk-context-scoped drift types (depends-on, exit-path), not only side-effect.
@test "BTS-667 AC-3a: new-fn depends-on re-attributes to the new fn (cmd_query)" {
  set -e
  run bash "$SCRIPT" diff-vs-manifest --diff "$REPO_ROOT/hub/tests/fixtures/manifest/diffs/new-fn-reattribution-depends-on.diff"
  echo "$output" | jq -e '[.drift[] | select(.drift_type == "new-depends-on-not-declared" and .id == "cmd_query" and .value == "linear-query.sh")] | length >= 1'
  echo "$output" | jq -e '[.drift[] | select(.drift_type == "new-depends-on-not-declared" and .id == "cmd_extract")] | length == 0'
}

@test "BTS-667 AC-3b: new-fn exit-path re-attributes to the new fn (cmd_query)" {
  set -e
  run bash "$SCRIPT" diff-vs-manifest --diff "$REPO_ROOT/hub/tests/fixtures/manifest/diffs/new-fn-reattribution-exit-path.diff"
  echo "$output" | jq -e '[.drift[] | select(.drift_type == "new-exit-path-not-declared" and .id == "cmd_query" and .value == "7")] | length >= 1'
  echo "$output" | jq -e '[.drift[] | select(.drift_type == "new-exit-path-not-declared" and .id == "cmd_extract")] | length == 0'
}

# BTS-667 AC-4: the `function name() {` and `function name {` keyword forms are
# recognized AND resolved to the bare name, so the body marker attributes to the
# new function (cmd_query) — requires extending _diff_ctx_to_primitive_id.
@test "BTS-667 AC-4a: function-keyword form with parens re-attributes to the new fn" {
  set -e
  run bash "$SCRIPT" diff-vs-manifest --diff "$REPO_ROOT/hub/tests/fixtures/manifest/diffs/new-fn-reattribution-function-form.diff"
  echo "$output" | jq -e '[.drift[] | select(.drift_type == "new-side-effect-not-declared" and .id == "cmd_query" and .value == "writes-undeclared-marker")] | length >= 1'
  echo "$output" | jq -e '[.drift[] | select(.drift_type == "new-side-effect-not-declared" and .id == "cmd_extract")] | length == 0'
}

@test "BTS-667 AC-4b: function-keyword form without parens re-attributes to the new fn" {
  set -e
  run bash "$SCRIPT" diff-vs-manifest --diff "$REPO_ROOT/hub/tests/fixtures/manifest/diffs/new-fn-reattribution-function-noparen.diff"
  echo "$output" | jq -e '[.drift[] | select(.drift_type == "new-side-effect-not-declared" and .id == "cmd_query" and .value == "writes-undeclared-marker")] | length >= 1'
  echo "$output" | jq -e '[.drift[] | select(.drift_type == "new-side-effect-not-declared" and .id == "cmd_extract")] | length == 0'
}

# BTS-667 AC-6: a marker at file scope (empty xfuncname header, no function-def among
# added lines) resolves to an empty prim_id and is skipped — the fix introduces no new
# false positive.
@test "BTS-667 AC-6: file-scope marker with no enclosing fn is skipped (no false drift)" {
  set -e
  run bash "$SCRIPT" diff-vs-manifest --diff "$REPO_ROOT/hub/tests/fixtures/manifest/diffs/new-fn-reattribution-file-scope.diff"
  echo "$output" | jq -e '[.drift[] | select(.drift_type == "new-side-effect-not-declared" and .value == "writes-x")] | length == 0'
}
