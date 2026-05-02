#!/usr/bin/env bats
# BTS-267: cmd_seed_allowlist — proposes initial manifest allowlist for a downstream-node substrate.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/.ccanvil/scripts/module-manifest.sh"
}

# AC-4: nonexistent --dir → exit 2 with stderr error.
@test "seed-allowlist: nonexistent --dir exits 2 with directory-not-found stderr" {
  run bash "$SCRIPT" seed-allowlist --dir /nonexistent/path/$$
  [ "$status" -eq 2 ]
  [[ "$output" =~ "directory not found" ]]
}
