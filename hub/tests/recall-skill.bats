#!/usr/bin/env bats
# BTS-20 — drift-guards for /recall consuming the unified lifecycle-state primitive.
#
# These tests pin the recall skill's adoption of the new envelope so future
# edits cannot silently revert to separate validate + recommend invocations.

bats_require_minimum_version 1.5.0

REPO_ROOT="$BATS_TEST_DIRNAME/../.."
SKILL="$REPO_ROOT/.claude/skills/recall/SKILL.md"

@test "AC-7: recall skill exists" {
  [ -f "$SKILL" ]
}

@test "AC-7: recall skill consumes lifecycle-state primitive" {
  grep -qF 'docs-check.sh lifecycle-state' "$SKILL"
}

@test "AC-7: recall skill does NOT call validate and recommend separately at top of data-gathering" {
  # The migration replaces the old 'validate' + 'recommend' call pair with a
  # single 'lifecycle-state' call. After migration, the skill should not have
  # both 'docs-check.sh validate' AND 'docs-check.sh recommend' invocations
  # in the data-gathering section. We allow either one to be referenced
  # inside narrative prose (e.g., "lifecycle-state composes validate +
  # recommend output") but not as separate command invocations.
  #
  # Heuristic: count lines that look like command invocations of validate and
  # recommend. If both appear as commands, the migration regressed.
  local validate_cmd_count recommend_cmd_count
  validate_cmd_count=$(grep -cE 'docs-check\.sh validate([^a-z-]|$)' "$SKILL" || true)
  recommend_cmd_count=$(grep -cE 'docs-check\.sh recommend([^a-z-]|$)' "$SKILL" || true)
  if (( validate_cmd_count > 0 && recommend_cmd_count > 0 )); then
    echo "regression: skill invokes both validate and recommend separately ($validate_cmd_count + $recommend_cmd_count)" >&2
    return 1
  fi
}

@test "AC-8: recall briefing prose mentions 'legal next actions'" {
  grep -qiF 'legal next actions' "$SKILL"
}

@test "AC-8: recall briefing prose mentions blockers from the envelope" {
  grep -qiE 'blockers' "$SKILL"
}

@test "AC-8: recall surfaces the lifecycle state in the briefing" {
  # Either via "Lifecycle state:" or "state:" referenced from the envelope.
  # Pre-migration prose had 'Lifecycle state:' so this guard tightens the
  # post-migration surface.
  grep -qiE 'Lifecycle state' "$SKILL"
}
