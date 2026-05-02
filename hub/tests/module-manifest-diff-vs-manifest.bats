#!/usr/bin/env bats
# BTS-268: cmd_diff_vs_manifest substrate — deterministic Layer 3 ramp.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/.ccanvil/scripts/module-manifest.sh"
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
