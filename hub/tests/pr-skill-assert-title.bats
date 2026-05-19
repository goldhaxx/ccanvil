#!/usr/bin/env bats
# BTS-178 — drift-guard: /pr skill prose contains the assert-pr-title call
# after `gh pr ready` so the squash-merge commit on main carries the correct
# subject.

bats_require_minimum_version 1.5.0

# BTS-497 telemetry hooks.
source "$BATS_TEST_DIRNAME/_helpers/telemetry.bash"
setup_file()    { telemetry_setup_file; }
teardown_file() { telemetry_teardown_file; }
setup()         { telemetry_setup; }
teardown()      { telemetry_teardown; }

PR_SKILL="$BATS_TEST_DIRNAME/../../.claude/commands/pr.md"

# =========================================================================
# AC-7: skill drift-guard
# =========================================================================

@test "AC-7: /pr skill prose references docs-check.sh assert-pr-title" {
  set -e
  [ -f "$PR_SKILL" ]
  grep -q "docs-check.sh assert-pr-title" "$PR_SKILL"
}

@test "AC-7: assert-pr-title call is positioned in the post-'gh pr ready' section" {
  set -e
  # Find line numbers of `gh pr ready` and `assert-pr-title`. The latter
  # must come AFTER the former — the title fix lands before merge, after
  # the PR has been marked ready.
  local ready_line assert_line
  ready_line=$(grep -n "gh pr ready" "$PR_SKILL" | head -1 | cut -d: -f1)
  assert_line=$(grep -n "assert-pr-title" "$PR_SKILL" | head -1 | cut -d: -f1)
  [ -n "$ready_line" ]
  [ -n "$assert_line" ]
  [ "$assert_line" -ge "$ready_line" ]
}
