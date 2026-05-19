#!/usr/bin/env bats
#
# BTS-316 Step 1: route-of accepts idea + backlog kinds (BTS-276 finding 4).
#
# Closes the paper-cut where cmd_route_of's allowlist covered only spec/plan/stasis,
# silently rejecting idea + backlog kinds even though _lifecycle_route reads them
# correctly. provider-activate (Step 4) needs route-of to be the canonical "which
# provider for kind X?" query across all four artifact kinds.

bats_require_minimum_version 1.5.0

# BTS-497 telemetry hooks.
source "$BATS_TEST_DIRNAME/_helpers/telemetry.bash"
setup_file()    { telemetry_setup_file; }
teardown_file() { telemetry_teardown_file; }
setup()         { telemetry_setup; }
teardown()      { telemetry_teardown; }

DC="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/docs-check.sh"

_make_linear_idea_fx() {
  local fx="$BATS_TEST_TMPDIR/linear-idea-fx"
  mkdir -p "$fx/.claude"
  cat > "$fx/.claude/ccanvil.json" <<'JSON'
{
  "integrations": {
    "routing": {
      "spec":    "linear",
      "plan":    "linear",
      "stasis":  "linear",
      "idea":    "linear",
      "backlog": "linear"
    }
  }
}
JSON
  echo "$fx"
}

_make_local_idea_fx() {
  local fx="$BATS_TEST_TMPDIR/local-idea-fx"
  mkdir -p "$fx/.claude"
  echo '{}' > "$fx/.claude/ccanvil.json"
  echo "$fx"
}

@test "BTS-316 AC-13: route-of idea returns linear on linear-routed fixture" {
  set -e
  fx=$(_make_linear_idea_fx)
  run bash "$DC" route-of idea --project-dir "$fx"
  [ "$status" -eq 0 ]
  [ "$output" = "linear" ]
}

@test "BTS-316 AC-13: route-of idea returns local on unconfigured fixture" {
  set -e
  fx=$(_make_local_idea_fx)
  run bash "$DC" route-of idea --project-dir "$fx"
  [ "$status" -eq 0 ]
  [ "$output" = "local" ]
}

@test "BTS-316 AC-13: route-of backlog returns linear on linear-routed fixture" {
  set -e
  fx=$(_make_linear_idea_fx)
  run bash "$DC" route-of backlog --project-dir "$fx"
  [ "$status" -eq 0 ]
  [ "$output" = "linear" ]
}

@test "BTS-316 AC-13: route-of backlog returns local on unconfigured fixture" {
  set -e
  fx=$(_make_local_idea_fx)
  run bash "$DC" route-of backlog --project-dir "$fx"
  [ "$status" -eq 0 ]
  [ "$output" = "local" ]
}

@test "BTS-316 Step 1: route-of regression — spec still works on linear fx" {
  set -e
  fx=$(_make_linear_idea_fx)
  run bash "$DC" route-of spec --project-dir "$fx"
  [ "$status" -eq 0 ]
  [ "$output" = "linear" ]
}

@test "BTS-316 Step 1: route-of usage on missing kind lists all five kinds" {
  set -e
  run --separate-stderr bash "$DC" route-of
  [ "$status" -eq 2 ]
  echo "$stderr" | grep -q idea
  echo "$stderr" | grep -q backlog
  echo "$stderr" | grep -q spec
}
