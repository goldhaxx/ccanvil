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
