#!/usr/bin/env bats
# BTS-239 Step 1: cmd_extract — AC-2 (extract) + AC-10 (malformed manifest)

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/.ccanvil/scripts/module-manifest.sh"
  FIXTURES="$REPO_ROOT/hub/tests/fixtures/manifest"
}

@test "extract: emits [] for file with no @manifest blocks" {
  set -e
  empty_file="$BATS_TEST_TMPDIR/empty.sh"
  printf '#!/usr/bin/env bash\necho hi\n' > "$empty_file"
  run bash "$SCRIPT" extract "$empty_file"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'type == "array" and length == 0'
}

@test "extract: emits one JSON object per @manifest block" {
  set -e
  run bash "$SCRIPT" extract "$FIXTURES/two-blocks.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'length == 2'
}

@test "extract: id field carries the function name (scalar string)" {
  set -e
  run bash "$SCRIPT" extract "$FIXTURES/two-blocks.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[0].id == "func_one"'
  echo "$output" | jq -e '.[1].id == "func_two"'
}

@test "extract: scalar fields stay scalars (purpose)" {
  set -e
  run bash "$SCRIPT" extract "$FIXTURES/two-blocks.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[0].purpose | type == "string"'
  echo "$output" | jq -e '.[0].purpose == "First block test fixture"'
}

@test "extract: array-shaped fields (failure-mode) are JSON arrays" {
  set -e
  run bash "$SCRIPT" extract "$FIXTURES/two-blocks.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[0]."failure-mode" | type == "array"'
  echo "$output" | jq -e '.[0]."failure-mode" | length == 1'
}

@test "extract: repeated keys collapse to JSON arrays" {
  set -e
  run bash "$SCRIPT" extract "$FIXTURES/multi-caller.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[0].caller | length == 2'
  echo "$output" | jq -e '.[0].caller[0] == "cmd_a"'
  echo "$output" | jq -e '.[0].caller[1] == "cmd_b"'
}

@test "extract: malformed failure-mode (empty id) exits 2 with MALFORMED stderr" {
  run bash "$SCRIPT" extract "$FIXTURES/malformed-failure-mode.sh"
  [ "$status" -eq 2 ]
  [[ "$output" =~ MALFORMED ]]
}
