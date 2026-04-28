#!/usr/bin/env bats
# BTS-239 Step 10: drift-guard with mutation tests — AC-8.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/.ccanvil/scripts/module-manifest.sh"
  PROJ="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$PROJ/.ccanvil/scripts" "$PROJ/.ccanvil/state"
  # Stage a single greenfield fixture as the only source.
  cp "$REPO_ROOT/hub/tests/fixtures/manifest/valid-deep.sh" "$PROJ/.ccanvil/scripts/valid-deep.sh"
  echo ".ccanvil/scripts/valid-deep.sh:valid_deep_func" > "$PROJ/.ccanvil/manifest-allowlist.txt"
}

@test "drift-guard clean state: validate exits 0" {
  set -e
  cd "$PROJ"
  run bash "$SCRIPT" validate --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.coverage.covered == 1'
  echo "$output" | jq -e '.status == "ok"'
}

@test "drift-guard mutation: corrupt caller field → exit 2 with DRIFT stderr" {
  cd "$PROJ"
  # Initial: clean.
  bash "$SCRIPT" validate --json >/dev/null
  # Mutation: replace `caller: referenced_caller` with a non-existent caller.
  sed -i.bak 's/^# caller: referenced_caller$/# caller: ghost_caller_xyz/' .ccanvil/scripts/valid-deep.sh
  run bash "$SCRIPT" validate --json
  [ "$status" -eq 2 ]
  [[ "$output" =~ "DRIFT" ]]
  [[ "$output" =~ "caller-not-found" ]]
  [[ "$output" =~ "ghost_caller_xyz" ]]
  # Revert.
  mv .ccanvil/scripts/valid-deep.sh.bak .ccanvil/scripts/valid-deep.sh
  run bash "$SCRIPT" validate --json
  [ "$status" -eq 0 ]
}

@test "drift-guard mutation: remove failure-mode marker → exit 2 with missing-failure-mode-marker" {
  cd "$PROJ"
  bash "$SCRIPT" validate --json >/dev/null
  # Remove the @failure-mode marker line from the body.
  sed -i.bak '/^[[:space:]]*#[[:space:]]*@failure-mode:[[:space:]]*foo/d' .ccanvil/scripts/valid-deep.sh
  run bash "$SCRIPT" validate --json
  [ "$status" -eq 2 ]
  [[ "$output" =~ "missing-failure-mode-marker" ]]
  mv .ccanvil/scripts/valid-deep.sh.bak .ccanvil/scripts/valid-deep.sh
  run bash "$SCRIPT" validate --json
  [ "$status" -eq 0 ]
}

@test "drift-guard mutation: remove side-effect marker → exit 2 with missing-side-effect-marker" {
  cd "$PROJ"
  bash "$SCRIPT" validate --json >/dev/null
  sed -i.bak '/^[[:space:]]*#[[:space:]]*@side-effect:[[:space:]]*writes-tmp/d' .ccanvil/scripts/valid-deep.sh
  run bash "$SCRIPT" validate --json
  [ "$status" -eq 2 ]
  [[ "$output" =~ "missing-side-effect-marker" ]]
  mv .ccanvil/scripts/valid-deep.sh.bak .ccanvil/scripts/valid-deep.sh
  run bash "$SCRIPT" validate --json
  [ "$status" -eq 0 ]
}

@test "drift-guard mutation: remove required key (purpose) → exit 2 with missing-required-key" {
  cd "$PROJ"
  bash "$SCRIPT" validate --json >/dev/null
  sed -i.bak '/^# purpose:/d' .ccanvil/scripts/valid-deep.sh
  run bash "$SCRIPT" validate --json
  [ "$status" -eq 2 ]
  [[ "$output" =~ "missing-required-key" ]]
  [[ "$output" =~ "purpose" ]]
  mv .ccanvil/scripts/valid-deep.sh.bak .ccanvil/scripts/valid-deep.sh
  run bash "$SCRIPT" validate --json
  [ "$status" -eq 0 ]
}

@test "drift-guard production allowlist clean (regression guard against this branch)" {
  set -e
  cd "$REPO_ROOT"
  run bash "$SCRIPT" validate --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.coverage.covered == .coverage.total'
}
