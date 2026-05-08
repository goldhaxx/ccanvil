#!/usr/bin/env bats
#
# BTS-316 Step 2: 3-tier merge_config (operator → hub → node).
#
# Adds the operator-config tier at $HOME/.ccanvil/operator.json above the existing
# hub + node tiers. Precedence: operator provides defaults; hub overrides operator;
# node overrides both. Mirrors the 2-tier semantics when operator file is absent
# (no behavior change on existing nodes).

bats_require_minimum_version 1.5.0

OPS="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/operations.sh"

setup() {
  # Isolate $HOME per test so operator.json writes don't pollute the real one
  # and missing-tier cases are deterministic.
  export HOME="$BATS_TEST_TMPDIR/fake-home"
  mkdir -p "$HOME/.ccanvil"
}

_node_with() {
  # _node_with <fixture-dir> <hub-json> <node-json>
  # Empty string means "skip this tier".
  local fx="$1"; shift
  local hub="$1"; shift
  local node="$1"; shift
  mkdir -p "$fx/.claude"
  if [[ -n "$hub" ]]; then
    echo "$hub" > "$fx/.claude/ccanvil.json"
  fi
  if [[ -n "$node" ]]; then
    echo "$node" > "$fx/.claude/ccanvil.local.json"
  fi
}

@test "BTS-316 AC-5: merge_config 3-tier — operator-only returns operator content" {
  set -e
  echo '{"providers":{"linear":{"team":"Op-Team"}}}' > "$HOME/.ccanvil/operator.json"
  fx="$BATS_TEST_TMPDIR/fx"
  _node_with "$fx" "" ""
  run bash "$OPS" merge-config --project-dir "$fx"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.providers.linear.team == "Op-Team"' >/dev/null
}

@test "BTS-316 AC-5: merge_config 3-tier — hub overrides operator" {
  set -e
  echo '{"providers":{"linear":{"team":"Op-Team","project":"op-default"}}}' > "$HOME/.ccanvil/operator.json"
  fx="$BATS_TEST_TMPDIR/fx"
  _node_with "$fx" '{"providers":{"linear":{"team":"Hub-Team"}}}' ""
  run bash "$OPS" merge-config --project-dir "$fx"
  [ "$status" -eq 0 ]
  # team: hub wins over operator
  echo "$output" | jq -e '.providers.linear.team == "Hub-Team"' >/dev/null
  # project: only operator has it, must survive
  echo "$output" | jq -e '.providers.linear.project == "op-default"' >/dev/null
}

@test "BTS-316 AC-5: merge_config 3-tier — node overrides hub overrides operator" {
  set -e
  echo '{"providers":{"linear":{"team":"Op-Team","project":"op-default","label":"op-label"}}}' > "$HOME/.ccanvil/operator.json"
  fx="$BATS_TEST_TMPDIR/fx"
  _node_with "$fx" \
    '{"providers":{"linear":{"team":"Hub-Team","project":"hub-default"}}}' \
    '{"providers":{"linear":{"team":"Node-Team"}}}'
  run bash "$OPS" merge-config --project-dir "$fx"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.providers.linear.team == "Node-Team"' >/dev/null
  echo "$output" | jq -e '.providers.linear.project == "hub-default"' >/dev/null
  echo "$output" | jq -e '.providers.linear.label == "op-label"' >/dev/null
}

@test "BTS-316 AC-5: merge_config 3-tier — operator + node (no hub)" {
  set -e
  echo '{"providers":{"linear":{"team":"Op-Team"}}}' > "$HOME/.ccanvil/operator.json"
  fx="$BATS_TEST_TMPDIR/fx"
  _node_with "$fx" "" '{"providers":{"linear":{"team":"Node-Team"}}}'
  run bash "$OPS" merge-config --project-dir "$fx"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.providers.linear.team == "Node-Team"' >/dev/null
}

@test "BTS-316 AC-5: merge_config — missing operator tier preserves 2-tier behavior" {
  set -e
  # No operator.json file. Hub + node behave exactly as today.
  fx="$BATS_TEST_TMPDIR/fx"
  _node_with "$fx" '{"a":"hub-a","b":"hub-b"}' '{"b":"node-b"}'
  run bash "$OPS" merge-config --project-dir "$fx"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.a == "hub-a"' >/dev/null
  echo "$output" | jq -e '.b == "node-b"' >/dev/null
}

@test "BTS-316 AC-5: merge_config — all tiers missing returns {}" {
  set -e
  fx="$BATS_TEST_TMPDIR/fx"
  mkdir -p "$fx/.claude"
  # No operator.json, no hub, no node.
  run bash "$OPS" merge-config --project-dir "$fx"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '. == {}' >/dev/null
}

@test "BTS-316 AC-6: merge_config — invalid operator JSON exits 1 with named error" {
  echo 'this is not json {' > "$HOME/.ccanvil/operator.json"
  fx="$BATS_TEST_TMPDIR/fx"
  _node_with "$fx" '{"valid":true}' ""
  run --separate-stderr bash "$OPS" merge-config --project-dir "$fx"
  [ "$status" -eq 1 ]
  echo "$stderr" | grep -q operator.json
}

@test "BTS-316 AC-5: merge_config — operator-only when hub + node both missing" {
  set -e
  echo '{"only":"operator"}' > "$HOME/.ccanvil/operator.json"
  fx="$BATS_TEST_TMPDIR/fx"
  mkdir -p "$fx/.claude"
  run bash "$OPS" merge-config --project-dir "$fx"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.only == "operator"' >/dev/null
}
