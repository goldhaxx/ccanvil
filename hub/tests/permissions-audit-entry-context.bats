#!/usr/bin/env bats
# BTS-161: permissions-audit.sh entry-context substrate
#
# Each test creates an isolated fixture dir with settings + log files.

bats_require_minimum_version 1.5.0

SCRIPT="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/permissions-audit.sh"

setup() {
  FIXTURE=$(mktemp -d)
  echo '{"entries":{}}' > "$FIXTURE/permissions-log.json"
}

teardown() {
  rm -rf "$FIXTURE"
}


# =========================================================================
# AC-1: JSON envelope shape — five top-level keys, permission echoed verbatim
# =========================================================================

@test "AC-1: entry-context emits JSON object with five top-level keys" {
  set -e
  cat > "$FIXTURE/settings.json" <<'EOF'
{ "permissions": { "allow": ["Bash(ls:*)"] } }
EOF
  run bash "$SCRIPT" entry-context "Bash(ls:*)" --settings-dir "$FIXTURE"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.permission == "Bash(ls:*)"'
  echo "$output" | jq -e 'has("source_files")'
  echo "$output" | jq -e 'has("matched_pattern")'
  echo "$output" | jq -e 'has("matched_hooks")'
  echo "$output" | jq -e 'has("introduced_in")'
}

@test "AC-1: entry-context echoes permission with parens and asterisks intact" {
  set -e
  cat > "$FIXTURE/settings.json" <<'EOF'
{ "permissions": { "allow": ["Bash(git status:*)"] } }
EOF
  run bash "$SCRIPT" entry-context "Bash(git status:*)" --settings-dir "$FIXTURE"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.permission == "Bash(git status:*)"'
}


# =========================================================================
# AC-2: source_files derivation
# =========================================================================

@test "AC-2: source_files for permission only in settings.json" {
  set -e
  cat > "$FIXTURE/settings.json" <<'EOF'
{ "permissions": { "allow": ["Bash(ls:*)"] } }
EOF
  run bash "$SCRIPT" entry-context "Bash(ls:*)" --settings-dir "$FIXTURE"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e --arg p "$FIXTURE/settings.json" '.source_files == [$p]'
}

@test "AC-2: source_files for permission only in settings.local.json" {
  set -e
  cat > "$FIXTURE/settings.local.json" <<'EOF'
{ "permissions": { "allow": ["Bash(ls:*)"] } }
EOF
  run bash "$SCRIPT" entry-context "Bash(ls:*)" --settings-dir "$FIXTURE"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e --arg p "$FIXTURE/settings.local.json" '.source_files == [$p]'
}

@test "AC-2: source_files for permission in both files (sorted)" {
  set -e
  cat > "$FIXTURE/settings.json" <<'EOF'
{ "permissions": { "allow": ["Bash(ls:*)"] } }
EOF
  cat > "$FIXTURE/settings.local.json" <<'EOF'
{ "permissions": { "allow": ["Bash(ls:*)"] } }
EOF
  run bash "$SCRIPT" entry-context "Bash(ls:*)" --settings-dir "$FIXTURE"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e --arg a "$FIXTURE/settings.json" --arg b "$FIXTURE/settings.local.json" \
    '.source_files == [$a, $b]'
}

@test "AC-2: source_files empty when permission absent from both files" {
  set -e
  cat > "$FIXTURE/settings.json" <<'EOF'
{ "permissions": { "allow": ["Bash(other:*)"] } }
EOF
  run bash "$SCRIPT" entry-context "Bash(missing:*)" --settings-dir "$FIXTURE"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.source_files == []'
}


# =========================================================================
# AC-3: matched_pattern via check_danger
# =========================================================================

@test "AC-3: matched_pattern populated for DANGER-classified Bash(chmod:*)" {
  set -e
  cat > "$FIXTURE/settings.json" <<'EOF'
{ "permissions": { "allow": ["Bash(chmod:*)"] } }
EOF
  run bash "$SCRIPT" entry-context "Bash(chmod:*)" --settings-dir "$FIXTURE"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.matched_pattern != null'
  echo "$output" | jq -e '.matched_pattern | length > 0'
}

@test "AC-3: matched_pattern null for non-DANGER Bash(ls:*)" {
  set -e
  cat > "$FIXTURE/settings.json" <<'EOF'
{ "permissions": { "allow": ["Bash(ls:*)"] } }
EOF
  run bash "$SCRIPT" entry-context "Bash(ls:*)" --settings-dir "$FIXTURE"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.matched_pattern == null'
}

@test "AC-3: matched_pattern null for non-Bash permission shape" {
  set -e
  cat > "$FIXTURE/settings.json" <<'EOF'
{ "permissions": { "allow": ["Read(//Users/foo)"] } }
EOF
  run bash "$SCRIPT" entry-context "Read(//Users/foo)" --settings-dir "$FIXTURE"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.matched_pattern == null'
}


# =========================================================================
# AC-6: positional arg required → exit 2 with specific error on stderr
# =========================================================================

@test "AC-6: entry-context with no positional arg exits 2 and explains why" {
  run bash "$SCRIPT" entry-context --settings-dir "$FIXTURE"
  [ "$status" -eq 2 ]
  # Stderr (or output) must mention the missing permission arg specifically —
  # generic 'Usage:' fallback is not enough; the error must be specific to
  # entry-context's missing-arg branch.
  combined="${stderr}${output}"
  [[ "$combined" == *"entry-context requires a permission"* ]]
}
