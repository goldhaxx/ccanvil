#!/usr/bin/env bats
# BTS-239 Step 2: cmd_index — AC-5

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/.ccanvil/scripts/module-manifest.sh"
  FIXTURES="$REPO_ROOT/hub/tests/fixtures/manifest"
}

# Helper: build a project-shaped fixture tree at $1 with two source files.
_setup_project() {
  local root="$1"
  mkdir -p "$root/.ccanvil/scripts" "$root/.ccanvil/state"
  cp "$FIXTURES/two-blocks.sh" "$root/.ccanvil/scripts/file-a.sh"
  cp "$FIXTURES/multi-caller.sh" "$root/.ccanvil/scripts/file-b.sh"
}

@test "index: writes .ccanvil/state/manifests.json with all blocks" {
  set -e
  proj="$BATS_TEST_TMPDIR/proj"
  _setup_project "$proj"
  cd "$proj"
  run bash "$SCRIPT" index
  [ "$status" -eq 0 ]
  [ -f ".ccanvil/state/manifests.json" ]
  echo "Result: $(cat .ccanvil/state/manifests.json)" >&2
  count=$(jq 'length' .ccanvil/state/manifests.json)
  [ "$count" -eq 3 ]
}

@test "index: keys are lexicographically sorted" {
  set -e
  proj="$BATS_TEST_TMPDIR/proj"
  _setup_project "$proj"
  cd "$proj"
  run bash "$SCRIPT" index
  [ "$status" -eq 0 ]
  keys=$(jq -r 'keys | join(",")' .ccanvil/state/manifests.json)
  expected=".ccanvil/scripts/file-a.sh:func_one,.ccanvil/scripts/file-a.sh:func_two,.ccanvil/scripts/file-b.sh:multi_caller_func"
  [ "$keys" = "$expected" ]
}

@test "index: deterministic across two runs (byte-identical)" {
  set -e
  proj="$BATS_TEST_TMPDIR/proj"
  _setup_project "$proj"
  cd "$proj"
  run bash "$SCRIPT" index
  [ "$status" -eq 0 ]
  hash1=$(shasum .ccanvil/state/manifests.json | awk '{print $1}')
  sleep 1  # ensure mtime would differ if non-deterministic
  run bash "$SCRIPT" index
  [ "$status" -eq 0 ]
  hash2=$(shasum .ccanvil/state/manifests.json | awk '{print $1}')
  [ "$hash1" = "$hash2" ]
}

@test "index: each entry preserves the manifest object shape" {
  set -e
  proj="$BATS_TEST_TMPDIR/proj"
  _setup_project "$proj"
  cd "$proj"
  run bash "$SCRIPT" index
  [ "$status" -eq 0 ]
  jq -e '.[".ccanvil/scripts/file-a.sh:func_one"].id == "func_one"' .ccanvil/state/manifests.json
  jq -e '.[".ccanvil/scripts/file-a.sh:func_one"].purpose == "First block test fixture"' .ccanvil/state/manifests.json
  jq -e '.[".ccanvil/scripts/file-b.sh:multi_caller_func"].caller | length == 2' .ccanvil/state/manifests.json
}

@test "index: emits {} when no .sh files in source dirs" {
  set -e
  proj="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$proj/.ccanvil/state"
  cd "$proj"
  run bash "$SCRIPT" index
  [ "$status" -eq 0 ]
  [ -f ".ccanvil/state/manifests.json" ]
  content=$(cat .ccanvil/state/manifests.json)
  [ "$content" = "{}" ]
}
