#!/usr/bin/env bats

# BTS-497 telemetry hooks.
source "$BATS_TEST_DIRNAME/_helpers/telemetry.bash"
setup_file()    { telemetry_setup_file; }
teardown_file() { telemetry_teardown_file; }
teardown()      { telemetry_teardown; }
# BTS-270: cmd_query lens flags — by-side-effect / callers-of / depends-on / by-failure-mode.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/.ccanvil/scripts/module-manifest.sh"
  telemetry_setup
}

# AC-1: existing positional shape still works.
@test "query: positional <key>:<value> shape still works (no regression)" {
  cd "$REPO_ROOT"
  run bash "$SCRIPT" query 'depends-on:jq'
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'type == "array"'
}

# AC-7: missing flag value → exit 2.
@test "query: --by-side-effect with no value exits 2" {
  cd "$REPO_ROOT"
  run bash "$SCRIPT" query --by-side-effect
  [ "$status" -eq 2 ]
  [[ "$output" =~ "requires a pattern" ]]
}

# AC-6: mutually exclusive with positional.
@test "query: flag + positional exits 2 (mutually exclusive)" {
  cd "$REPO_ROOT"
  run bash "$SCRIPT" query --by-side-effect writes 'depends-on:jq'
  [ "$status" -eq 2 ]
  [[ "$output" =~ "mutually exclusive" ]]
}

# AC-6: mutually exclusive with another flag.
@test "query: two lens flags exit 2 (mutually exclusive)" {
  cd "$REPO_ROOT"
  run bash "$SCRIPT" query --by-side-effect writes --depends-on jq
  [ "$status" -eq 2 ]
  [[ "$output" =~ "mutually exclusive" ]]
}

# AC-2: --by-side-effect returns matches with side-effect array surfaced.
@test "query: --by-side-effect surfaces matched primitives" {
  set -e
  cd "$REPO_ROOT"
  run bash "$SCRIPT" query --by-side-effect writes-
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'type == "array"'
  echo "$output" | jq -e 'length >= 1'
  # Every match has the field surfaced.
  echo "$output" | jq -e 'all(.["side-effect"] | length >= 1)'
}

# AC-4: --depends-on returns primitives whose depends-on includes the value.
@test "query: --depends-on jq surfaces matched primitives" {
  set -e
  cd "$REPO_ROOT"
  run bash "$SCRIPT" query --depends-on jq
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'type == "array"'
  echo "$output" | jq -e 'length >= 1'
  # All entries have "jq" in their depends-on.
  echo "$output" | jq -e 'all(.["depends-on"] | index("jq") != null)'
}

# AC-5: --by-failure-mode pattern match.
@test "query: --by-failure-mode usage-error surfaces matched primitives" {
  set -e
  cd "$REPO_ROOT"
  run bash "$SCRIPT" query --by-failure-mode usage-error
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'type == "array"'
  echo "$output" | jq -e 'length >= 1'
}

# AC-3: --callers-of returns empty array for unknown caller.
@test "query: --callers-of for unknown id returns empty array, exit 0" {
  set -e
  cd "$REPO_ROOT"
  run bash "$SCRIPT" query --callers-of skill:/never-exists-$$
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'type == "array"'
  echo "$output" | jq -e 'length == 0'
}
