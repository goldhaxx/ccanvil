#!/usr/bin/env bats
# Tests for scaffold.json + scaffold.local.json overlay merge behavior.
#
# Each test creates an isolated project directory with fixture configs.

OPERATIONS_SCRIPT="$BATS_TEST_DIRNAME/../scripts/operations.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  PROJECT=$(mktemp -d)
  mkdir -p "$PROJECT/.claude"
}

teardown() {
  rm -rf "$PROJECT"
}

# =========================================================================
# Step 1: Merge function core behavior (AC-1, AC-3, AC-4, AC-11)
# =========================================================================

@test "AC-1: both files present — deep merge produces combined result" {
  cat > "$PROJECT/.claude/scaffold.json" <<'EOF'
{"features":{"pr_review":false}}
EOF
  cat > "$PROJECT/.claude/scaffold.local.json" <<'EOF'
{"integrations":{"routing":{"backlog":"linear"}}}
EOF

  run bash "$OPERATIONS_SCRIPT" merge-config --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.features.pr_review == false'
  echo "$output" | jq -e '.integrations.routing.backlog == "linear"'
}

@test "AC-3: no local file — effective config equals hub file" {
  cat > "$PROJECT/.claude/scaffold.json" <<'EOF'
{"features":{"pr_review":false},"integrations":{}}
EOF

  run bash "$OPERATIONS_SCRIPT" merge-config --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.features.pr_review == false'
  echo "$output" | jq -e '.integrations == {}'
}

@test "AC-4: no hub file and no local file — empty JSON object, exit 0" {
  run bash "$OPERATIONS_SCRIPT" merge-config --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '. == {}'
}

# =========================================================================
# Step 2: Node-wins conflict behavior (AC-2)
# =========================================================================

@test "AC-2: node wins on conflict — local overrides hub value" {
  cat > "$PROJECT/.claude/scaffold.json" <<'EOF'
{"features":{"pr_review":false}}
EOF
  cat > "$PROJECT/.claude/scaffold.local.json" <<'EOF'
{"features":{"pr_review":true}}
EOF

  run bash "$OPERATIONS_SCRIPT" merge-config --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.features.pr_review == true'
}

@test "AC-11: deep merge preserves nested keys from both sides" {
  cat > "$PROJECT/.claude/scaffold.json" <<'EOF'
{"integrations":{"providers":{"github":{"mechanism":"cli"}}}}
EOF
  cat > "$PROJECT/.claude/scaffold.local.json" <<'EOF'
{"integrations":{"providers":{"linear":{"mechanism":"mcp"}}}}
EOF

  run bash "$OPERATIONS_SCRIPT" merge-config --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.integrations.providers | keys | length == 2'
  echo "$output" | jq -e '.integrations.providers.github.mechanism == "cli"'
  echo "$output" | jq -e '.integrations.providers.linear.mechanism == "mcp"'
}
