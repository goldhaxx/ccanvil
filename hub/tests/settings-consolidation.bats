#!/usr/bin/env bats
# BTS-603 — drift-guard for .claude/settings.json consolidation.
#
# Pins AC-3/4/5/6/7/8 structurally so future edits can't silently regress:
#   - AC-3: deny array contains every entry classified as the safe-superset
#   - AC-4: hook commands wired per event group
#   - AC-5: 9 shell control-flow keywords absent from allow
#   - AC-6: canonical no-./ path form survives; ./-prefix duplicates absent
#   - AC-7: 8 operator-personal entries live in settings.local.json, not in
#           the hub-shared settings.json
#   - AC-8: 2 project-shared MCP wildcards remain in settings.json

bats_require_minimum_version 1.5.0

# BTS-497 telemetry hooks.
source "$BATS_TEST_DIRNAME/_helpers/telemetry.bash"
setup_file()    { telemetry_setup_file; }
teardown_file() { telemetry_teardown_file; }

setup() {
  REPO_ROOT="$BATS_TEST_DIRNAME/../.."
  SETTINGS="$REPO_ROOT/.claude/settings.json"
  SETTINGS_LOCAL="$REPO_ROOT/.claude/settings.local.json"
  telemetry_setup
}

teardown() {
  telemetry_teardown
}

# ---------------------------------------------------------------------------
# AC-3 — deny-array safe-superset
# ---------------------------------------------------------------------------
@test "AC-3: deny array contains every pre-change destructive-shape entry" {
  local expected_deny='[
    "Bash(rm -rf /)*",
    "Bash(rm -rf /*)*",
    "Bash(rm -rf ~)*",
    "Bash(rm -rf $HOME)*",
    "Bash(rm -rf .)*",
    "Bash(sudo:*)",
    "Bash(su:*)",
    "Bash(doas:*)",
    "Bash(kill -9:*)",
    "Bash(dd:*)",
    "Bash(mkfs:*)",
    "Bash(diskutil:*)"
  ]'
  local missing
  missing=$(jq -n --argjson E "$expected_deny" --slurpfile S "$SETTINGS" \
    '[$E[] | . as $e | select(($S[0].permissions.deny | any(. == $e)) | not)]')
  [ "$missing" = "[]" ]
}

# ---------------------------------------------------------------------------
# AC-4 — per-event-group hook command preservation
# ---------------------------------------------------------------------------
# NOTE: AC-4 uses a jq exhaustive-check pattern (compute missing list, assert
# empty) rather than `for hook in ...; do grep -q ...; done` — bats does not
# enable errexit by default inside test bodies, so a naive for-loop short-
# circuits to the LAST iteration's exit code. The jq form catches partial
# coverage failures structurally.

@test "AC-4: PreToolUse hooks wired (protect-files, protect-main, guard-force-push, guard-destructive)" {
  local expected='["protect-files.sh","protect-main.sh","guard-force-push.sh","guard-destructive.sh"]'
  local missing
  missing=$(jq -n --argjson E "$expected" --slurpfile S "$SETTINGS" \
    '[$E[] | . as $e | select([$S[0].hooks.PreToolUse[]?.hooks[]?.command] | any(contains($e)) | not)]')
  [ "$missing" = "[]" ]
}

@test "AC-4: PostToolUse hooks wired (lint-on-write, format-on-write, branch-name-lint, commit-msg-lint)" {
  local expected='["lint-on-write.sh","format-on-write.sh","branch-name-lint.sh","commit-msg-lint.sh"]'
  local missing
  missing=$(jq -n --argjson E "$expected" --slurpfile S "$SETTINGS" \
    '[$E[] | . as $e | select([$S[0].hooks.PostToolUse[]?.hooks[]?.command] | any(contains($e)) | not)]')
  [ "$missing" = "[]" ]
}

@test "AC-4: PreCompact hook wired (post-compact-marker.sh)" {
  local expected='["post-compact-marker.sh"]'
  local missing
  missing=$(jq -n --argjson E "$expected" --slurpfile S "$SETTINGS" \
    '[$E[] | . as $e | select([$S[0].hooks.PreCompact[]?.hooks[]?.command] | any(contains($e)) | not)]')
  [ "$missing" = "[]" ]
}

@test "AC-4: SessionStart hooks wired (session-boundary.sh, session-otel-open.sh)" {
  local expected='["session-boundary.sh","session-otel-open.sh"]'
  local missing
  missing=$(jq -n --argjson E "$expected" --slurpfile S "$SETTINGS" \
    '[$E[] | . as $e | select([$S[0].hooks.SessionStart[]?.hooks[]?.command] | any(contains($e)) | not)]')
  [ "$missing" = "[]" ]
}

@test "AC-4: SessionEnd hook wired (session-otel-close.sh)" {
  local expected='["session-otel-close.sh"]'
  local missing
  missing=$(jq -n --argjson E "$expected" --slurpfile S "$SETTINGS" \
    '[$E[] | . as $e | select([$S[0].hooks.SessionEnd[]?.hooks[]?.command] | any(contains($e)) | not)]')
  [ "$missing" = "[]" ]
}

@test "AC-4: PermissionRequest hook wired (permission-request-suppress-redundant.sh)" {
  local expected='["permission-request-suppress-redundant.sh"]'
  local missing
  missing=$(jq -n --argjson E "$expected" --slurpfile S "$SETTINGS" \
    '[$E[] | . as $e | select([$S[0].hooks.PermissionRequest[]?.hooks[]?.command] | any(contains($e)) | not)]')
  [ "$missing" = "[]" ]
}

# ---------------------------------------------------------------------------
# AC-5 — shell control-flow keywords absent
# ---------------------------------------------------------------------------
@test "AC-5: 9 shell control-flow keyword entries are absent from allow" {
  local keywords='["Bash(for:*)","Bash(while:*)","Bash(if:*)","Bash(do:*)","Bash(done)","Bash(then:*)","Bash(else:*)","Bash(elif:*)","Bash(fi)"]'
  local present
  present=$(jq -n --argjson K "$keywords" --slurpfile S "$SETTINGS" \
    '[$K[] | . as $e | select($S[0].permissions.allow | any(. == $e))]')
  [ "$present" = "[]" ]
}

# ---------------------------------------------------------------------------
# AC-6 — canonical no-./ path form survives; ./-prefix duplicates absent
# ---------------------------------------------------------------------------
@test "AC-6: Bash(.ccanvil/scripts/:*) present (canonical no-./ form survives)" {
  result=$(jq '.permissions.allow | any(. == "Bash(.ccanvil/scripts/:*)")' "$SETTINGS")
  [ "$result" = "true" ]
}

@test "AC-6: Bash(./.ccanvil/scripts/:*) absent (./-prefix duplicate removed)" {
  result=$(jq '.permissions.allow | any(. == "Bash(./.ccanvil/scripts/:*)")' "$SETTINGS")
  [ "$result" = "false" ]
}

@test "AC-6: Bash(.claude/hooks/:*) present (canonical no-./ form survives)" {
  result=$(jq '.permissions.allow | any(. == "Bash(.claude/hooks/:*)")' "$SETTINGS")
  [ "$result" = "true" ]
}

@test "AC-6: Bash(./.claude/hooks/:*) absent (./-prefix duplicate removed)" {
  result=$(jq '.permissions.allow | any(. == "Bash(./.claude/hooks/:*)")' "$SETTINGS")
  [ "$result" = "false" ]
}

# ---------------------------------------------------------------------------
# AC-7 — 8 operator-personal entries moved from settings.json → settings.local.json
# ---------------------------------------------------------------------------
@test "AC-7: 8 personal entries absent from .claude/settings.json" {
  local personal='[
    "Read(//Users/zacharywright/projects/**)",
    "mcp__claude_ai_Notion__*",
    "mcp__claude_ai_Granola__*",
    "mcp__claude_ai_Gmail__*",
    "mcp__claude_ai_Google_Calendar__*",
    "mcp__claude_ai_Google_Drive__*",
    "mcp__open-brain__*",
    "mcp__claude-in-chrome__*"
  ]'
  local present
  present=$(jq -n --argjson P "$personal" --slurpfile S "$SETTINGS" \
    '[$P[] | . as $e | select($S[0].permissions.allow | any(. == $e))]')
  [ "$present" = "[]" ]
}

@test "AC-7: 8 personal entries present in .claude/settings.local.json" {
  # Skip on fresh clone: settings.local.json is gitignored and is generated
  # per-machine. AC-7's "absent-from-settings.json" test above carries the
  # regression-prevention load.
  [ -f "$SETTINGS_LOCAL" ] || skip "settings.local.json not present (gitignored / per-machine)"
  local personal='[
    "Read(//Users/zacharywright/projects/**)",
    "mcp__claude_ai_Notion__*",
    "mcp__claude_ai_Granola__*",
    "mcp__claude_ai_Gmail__*",
    "mcp__claude_ai_Google_Calendar__*",
    "mcp__claude_ai_Google_Drive__*",
    "mcp__open-brain__*",
    "mcp__claude-in-chrome__*"
  ]'
  local missing
  missing=$(jq -n --argjson P "$personal" --slurpfile L "$SETTINGS_LOCAL" \
    '[$P[] | . as $e | select(($L[0].permissions.allow // [] | any(. == $e)) | not)]')
  [ "$missing" = "[]" ]
}

@test "AC-7: 'ONLY this set' exclusivity — no settings.json allow entry leaks into settings.local.json" {
  [ -f "$SETTINGS_LOCAL" ] || skip "settings.local.json not present (gitignored / per-machine)"
  # Spec AC-7 says ONLY the 8 personal entries are duplicated in settings.local.json.
  # Any post-trim settings.json allow entry appearing in settings.local.json is a
  # silent copy-leak — fail loudly.
  local leaked
  leaked=$(jq -n --slurpfile S "$SETTINGS" --slurpfile L "$SETTINGS_LOCAL" \
    '[($L[0].permissions.allow // []) | .[] | select(. as $e | $S[0].permissions.allow | any(. == $e))]')
  [ "$leaked" = "[]" ]
}

# ---------------------------------------------------------------------------
# AC-8 — project-shared MCP wildcards stay in settings.json
# ---------------------------------------------------------------------------
@test "AC-8: mcp__claude_ai_Linear__* remains in settings.json (project-shared)" {
  result=$(jq '.permissions.allow | any(. == "mcp__claude_ai_Linear__*")' "$SETTINGS")
  [ "$result" = "true" ]
}

@test "AC-8: mcp__claude_ai_Mermaid_Chart__* remains in settings.json (project-shared)" {
  result=$(jq '.permissions.allow | any(. == "mcp__claude_ai_Mermaid_Chart__*")' "$SETTINGS")
  [ "$result" = "true" ]
}

# ---------------------------------------------------------------------------
# AC-11 — both files parse as valid JSON
# ---------------------------------------------------------------------------
@test "AC-11: .claude/settings.json parses as valid JSON" {
  jq . "$SETTINGS" > /dev/null
}

@test "AC-11: .claude/settings.local.json parses as valid JSON" {
  [ -f "$SETTINGS_LOCAL" ] || skip "settings.local.json not present (gitignored / per-machine)"
  jq . "$SETTINGS_LOCAL" > /dev/null
}
