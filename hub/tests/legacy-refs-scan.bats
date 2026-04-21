#!/usr/bin/env bats
# Tests for docs-check.sh legacy-refs-scan subcommand.
# Spec: docs/specs/stasis-recall.md AC-35 through AC-37.

SCRIPT="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/docs-check.sh"

setup() {
  FIXTURE=$(mktemp -d)
}

teardown() {
  rm -rf "$FIXTURE"
}

@test "legacy-refs-scan: exits 0 and emits empty array on clean project" {
  mkdir -p "$FIXTURE/.claude/rules"
  cat > "$FIXTURE/.claude/rules/workflow.md" <<'EOF'
# Workflow

Run /stasis before /compact.
Read docs/stasis.md after resume.
EOF
  run bash "$SCRIPT" legacy-refs-scan "$FIXTURE"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq 'length')" = "0" ]
}

@test "legacy-refs-scan: exits 1 and reports matches for legacy /catchup" {
  mkdir -p "$FIXTURE/.claude/rules"
  cat > "$FIXTURE/.claude/rules/workflow.md" <<'EOF'
# Workflow

Run /catchup after /compact.
EOF
  run bash "$SCRIPT" legacy-refs-scan "$FIXTURE"
  [ "$status" -eq 1 ]
  [ "$(echo "$output" | jq 'length')" -ge 1 ]
  match_found=$(echo "$output" | jq -r '.[] | select(.match | contains("/catchup")) | .file')
  [[ "$match_found" == *"workflow.md"* ]]
}

@test "legacy-refs-scan: detects docs/checkpoint.md reference" {
  mkdir -p "$FIXTURE/docs"
  cat > "$FIXTURE/docs/readme.md" <<'EOF'
See docs/checkpoint.md for session state.
EOF
  run bash "$SCRIPT" legacy-refs-scan "$FIXTURE"
  [ "$status" -eq 1 ]
  match_found=$(echo "$output" | jq -r '.[] | select(.match | contains("docs/checkpoint.md")) | .file')
  [[ "$match_found" == *"readme.md"* ]]
}

@test "legacy-refs-scan: detects stale-checkpoint state name" {
  mkdir -p "$FIXTURE/scripts"
  cat > "$FIXTURE/scripts/helper.sh" <<'EOF'
if [[ "$result" == "stale-checkpoint" ]]; then
  echo "stale"
fi
EOF
  run bash "$SCRIPT" legacy-refs-scan "$FIXTURE"
  [ "$status" -eq 1 ]
  match_found=$(echo "$output" | jq -r '.[] | select(.match | contains("stale-checkpoint")) | .file')
  [[ "$match_found" == *"helper.sh"* ]]
}

@test "legacy-refs-scan: classifies hub-owned vs node-specific scope via NODE-SPECIFIC marker" {
  mkdir -p "$FIXTURE/.claude/rules"
  cat > "$FIXTURE/.claude/rules/workflow.md" <<'EOF'
# Hub content

Run /catchup after /compact.

<!-- NODE-SPECIFIC-START -->
## Local additions

Also run /checkpoint before deploys.
EOF
  run bash "$SCRIPT" legacy-refs-scan "$FIXTURE"
  [ "$status" -eq 1 ]
  scopes=$(echo "$output" | jq -r '[.[] | .scope] | unique | sort | join(",")')
  [[ "$scopes" == *"hub-owned"* ]]
  [[ "$scopes" == *"node-specific"* ]]
}

@test "legacy-refs-scan: JSON entries have file, line, match, scope keys" {
  mkdir -p "$FIXTURE/.claude/rules"
  cat > "$FIXTURE/.claude/rules/workflow.md" <<'EOF'
Run /catchup now.
EOF
  run bash "$SCRIPT" legacy-refs-scan "$FIXTURE"
  [ "$status" -eq 1 ]
  first=$(echo "$output" | jq '.[0]')
  echo "$first" | jq -e '.file'
  echo "$first" | jq -e '.line'
  echo "$first" | jq -e '.match'
  echo "$first" | jq -e '.scope'
}

@test "legacy-refs-scan: skips binary files and .git directory" {
  mkdir -p "$FIXTURE/.git"
  echo "fake /catchup in .git" > "$FIXTURE/.git/config"
  printf '\x00\x01\x02/catchup\x03' > "$FIXTURE/binary"
  run bash "$SCRIPT" legacy-refs-scan "$FIXTURE"
  [ "$status" -eq 0 ]
}
