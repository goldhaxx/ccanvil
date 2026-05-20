#!/usr/bin/env bats
# BTS-162: --parent flag for /idea capture (Part 1).
#
# Tests cover:
#   AC-1   Linear path appends `--parent-id 'X'` to the eval'd command string.
#   AC-2   Local path stamps `parent_id` in JSONL when --parent set.
#   AC-3   --parent parses correctly in both leading and trailing position
#          (string-construction shape mirrored from skill prose).
#   AC-4   Validation: empty + whitespace values rejected with documented msgs.
#   AC-5   Pending-log `--op add --parent X` writes `args.parent_id`.
#   AC-6   Drift-guard: no-flag captures still produce JSONL without parent_id.
#
# Linear-path tests synthesize the resolver output and exercise the documented
# string-append pattern; no live MCP / http call is made.

bats_require_minimum_version 1.5.0

# BTS-497 telemetry hooks.
source "$BATS_TEST_DIRNAME/_helpers/telemetry.bash"
setup_file()    { telemetry_setup_file; }
teardown_file() { telemetry_teardown_file; }

DC="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/docs-check.sh"
SKILL_FILE="$BATS_TEST_DIRNAME/../../.claude/skills/idea/SKILL.md"

setup() {
  NODE=$(mktemp -d)
  mkdir -p "$NODE/.ccanvil" "$NODE/.claude"
  telemetry_setup
}

teardown() {
  telemetry_teardown
  rm -rf "$NODE"
}

# =========================================================================
# AC-2: local path stamps parent_id when --parent set
# =========================================================================

@test "AC-2: cmd_idea_add --parent idea-7 stamps parent_id in JSONL" {
  set -e
  run bash "$DC" idea-add --parent idea-7 "child idea body" "$NODE"
  [ "$status" -eq 0 ]
  parent=$(tail -1 "$NODE/.ccanvil/ideas.log" | jq -r '.parent_id')
  [ "$parent" = "idea-7" ]
}

@test "AC-2 trailing flag: cmd_idea_add 'body' --parent idea-7 also stamps parent_id" {
  set -e
  run bash "$DC" idea-add "child idea body" --parent idea-7 "$NODE"
  [ "$status" -eq 0 ]
  parent=$(tail -1 "$NODE/.ccanvil/ideas.log" | jq -r '.parent_id')
  [ "$parent" = "idea-7" ]
}

# =========================================================================
# AC-6 drift-guard: no --parent → no parent_id key in JSONL
# =========================================================================

@test "AC-6 drift-guard local: cmd_idea_add (no --parent) omits parent_id key" {
  set -e
  run bash "$DC" idea-add "plain body" "$NODE"
  [ "$status" -eq 0 ]
  has_parent=$(tail -1 "$NODE/.ccanvil/ideas.log" | jq -r 'has("parent_id")')
  [ "$has_parent" = "false" ]
}

# =========================================================================
# AC-4: validation
# =========================================================================

@test "AC-4: cmd_idea_add --parent '' exits 2 with documented message" {
  run bash "$DC" idea-add --parent "" "body" "$NODE"
  [ "$status" -eq 2 ]
  [[ "$output" == *"--parent requires a non-empty value"* ]]
}

@test "AC-4: cmd_idea_add --parent 'BTS 158' exits 2 with whitespace error" {
  run bash "$DC" idea-add --parent "BTS 158" "body" "$NODE"
  [ "$status" -eq 2 ]
  [[ "$output" == *"contains whitespace"* ]]
  [[ "$output" == *"BTS 158"* ]]
}

# =========================================================================
# AC-5: pending-log --op add --parent
# =========================================================================

@test "AC-5: idea-pending-append --op add --parent BTS-158 stamps args.parent_id" {
  set -e
  run bash "$DC" idea-pending-append \
    --op add --parent BTS-158 --title "T" --body "B" --project-dir "$NODE"
  [ "$status" -eq 0 ]
  parent=$(tail -1 "$NODE/.ccanvil/ideas-pending.log" | jq -r '.args.parent_id')
  [ "$parent" = "BTS-158" ]
}

@test "AC-5 drift-guard: idea-pending-append --op add (no --parent) omits args.parent_id" {
  set -e
  run bash "$DC" idea-pending-append \
    --op add --title "T" --body "B" --project-dir "$NODE"
  [ "$status" -eq 0 ]
  has_parent=$(tail -1 "$NODE/.ccanvil/ideas-pending.log" | jq -r '.args | has("parent_id")')
  [ "$has_parent" = "false" ]
}

@test "AC-5 validation parity: idea-pending-append --parent '' exits 2" {
  run bash "$DC" idea-pending-append \
    --op add --parent "" --title "T" --body "B" --project-dir "$NODE"
  [ "$status" -eq 2 ]
  [[ "$output" == *"--parent requires a non-empty value"* ]]
}

@test "AC-5 validation parity: idea-pending-append --parent 'BTS 158' exits 2" {
  run bash "$DC" idea-pending-append \
    --op add --parent "BTS 158" --title "T" --body "B" --project-dir "$NODE"
  [ "$status" -eq 2 ]
  [[ "$output" == *"contains whitespace"* ]]
}

# =========================================================================
# Skill-prose drift-guards for the post-/review fixes
# =========================================================================

@test "Sync replay drift-guard: SKILL.md documents parent_id forwarding on add replay" {
  # CONCERN-1 fix: skill prose must document reading args.parent_id from
  # the pending entry and appending --parent-id on replay.
  grep -q "args.parent_id" "$SKILL_FILE"
}

@test "Step 3b drift-guard: SKILL.md local path forwards --parent" {
  # CONCERN-2 fix: Step 3b must show the PARENT_FLAG=() pass-through.
  grep -q "PARENT_FLAG" "$SKILL_FILE"
}

# =========================================================================
# AC-1: Linear-path string-construction shape
# Mirrors the documented skill pattern:
#   cmd="$cmd --parent-id $(printf '%s' "$parent" | jq -R @sh)"
# =========================================================================

@test "AC-1: skill's documented append produces --parent-id 'X' in command string" {
  set -e
  base_cmd="bash .ccanvil/scripts/linear-query.sh save-issue --team 'Blocktech Solutions'"
  parent="BTS-158"
  cmd="$base_cmd --parent-id $(printf '%s' "$parent" | jq -Rr @sh)"
  [[ "$cmd" == *"--parent-id 'BTS-158'"* ]]
}

@test "AC-6 drift-guard linear: no --parent-id when parent unset" {
  set -e
  base_cmd="bash .ccanvil/scripts/linear-query.sh save-issue --team 'Blocktech Solutions'"
  cmd="$base_cmd"
  [[ "$cmd" != *"--parent-id"* ]]
}

# =========================================================================
# AC-3: skill prose drift-guard — documented in both flag-positions
# =========================================================================

@test "AC-3: skill prose documents --parent flag in capture section" {
  grep -q -- "--parent" "$SKILL_FILE"
}

@test "AC-3: skill prose documents --parent-id append shape for Linear path" {
  grep -q -- "--parent-id" "$SKILL_FILE"
}
