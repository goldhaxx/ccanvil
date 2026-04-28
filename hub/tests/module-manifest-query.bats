#!/usr/bin/env bats
# BTS-239 Step 3: cmd_query — AC-6

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/.ccanvil/scripts/module-manifest.sh"
  FIXTURES="$REPO_ROOT/hub/tests/fixtures/manifest"
}

_setup_project() {
  local root="$1"
  mkdir -p "$root/.ccanvil/scripts" "$root/.ccanvil/state"
  cp "$FIXTURES/two-blocks.sh" "$root/.ccanvil/scripts/file-a.sh"
  cp "$FIXTURES/multi-caller.sh" "$root/.ccanvil/scripts/file-b.sh"
}

@test "query: returns matching entries for array-field substring match" {
  set -e
  proj="$BATS_TEST_TMPDIR/proj"
  _setup_project "$proj"
  cd "$proj"
  bash "$SCRIPT" index >/dev/null
  run bash "$SCRIPT" query "depends-on:linear-query.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'length == 1'
  echo "$output" | jq -e '.[0].id == "multi_caller_func"'
}

@test "query: returns [] for no-match" {
  set -e
  proj="$BATS_TEST_TMPDIR/proj"
  _setup_project "$proj"
  cd "$proj"
  bash "$SCRIPT" index >/dev/null
  run bash "$SCRIPT" query "depends-on:nonexistent-thing"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'length == 0'
}

@test "query: regenerates index when source is newer than index" {
  set -e
  proj="$BATS_TEST_TMPDIR/proj"
  _setup_project "$proj"
  cd "$proj"
  bash "$SCRIPT" index >/dev/null

  index_mtime_before=$(stat -f %m .ccanvil/state/manifests.json 2>/dev/null || stat --format=%Y .ccanvil/state/manifests.json)

  sleep 1
  # Touch a source file to make it newer than the index.
  touch .ccanvil/scripts/file-a.sh

  bash "$SCRIPT" query "purpose:fixture" >/dev/null

  index_mtime_after=$(stat -f %m .ccanvil/state/manifests.json 2>/dev/null || stat --format=%Y .ccanvil/state/manifests.json)
  [ "$index_mtime_after" -gt "$index_mtime_before" ]
}

@test "query: regenerates index when index is missing" {
  set -e
  proj="$BATS_TEST_TMPDIR/proj"
  _setup_project "$proj"
  cd "$proj"
  # No prior index.
  [ ! -f .ccanvil/state/manifests.json ]
  run bash "$SCRIPT" query "id:func_one"
  [ "$status" -eq 0 ]
  [ -f .ccanvil/state/manifests.json ]
  echo "$output" | jq -e 'length == 1'
}

@test "query: matches scalar fields (purpose) by substring" {
  set -e
  proj="$BATS_TEST_TMPDIR/proj"
  _setup_project "$proj"
  cd "$proj"
  bash "$SCRIPT" index >/dev/null
  run bash "$SCRIPT" query "purpose:repeated keys"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'length == 1'
  echo "$output" | jq -e '.[0].id == "multi_caller_func"'
}

@test "query: rejects malformed expression (no colon)" {
  proj="$BATS_TEST_TMPDIR/proj"
  _setup_project "$proj"
  cd "$proj"
  run bash "$SCRIPT" query "no-colon-here"
  [ "$status" -eq 2 ]
}
