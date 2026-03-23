#!/usr/bin/env bats
# Tests for scripts/permissions-audit.sh
#
# Each test creates an isolated directory with fixture settings files.

SCRIPT="$BATS_TEST_DIRNAME/../scripts/permissions-audit.sh"

setup() {
  FIXTURE=$(mktemp -d)
}

teardown() {
  rm -rf "$FIXTURE"
}


# =========================================================================
# Step 1: Script skeleton + entry parsing (AC-1 partial)
# =========================================================================

@test "check outputs valid JSON with entries array" {
  cat > "$FIXTURE/settings.json" <<'EOF'
{
  "permissions": {
    "allow": [
      "Bash(git status:*)",
      "Bash(ls:*)",
      "Bash(diff:*)"
    ]
  }
}
EOF

  run bash "$SCRIPT" check --settings-dir "$FIXTURE"
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
  echo "$output" | jq -e '.entries | length == 3'
}

@test "each entry has permission, source, and status fields" {
  cat > "$FIXTURE/settings.json" <<'EOF'
{
  "permissions": {
    "allow": ["Bash(git status:*)"]
  }
}
EOF

  run bash "$SCRIPT" check --settings-dir "$FIXTURE"
  echo "$output" | jq -e '.entries[0].permission == "Bash(git status:*)"'
  echo "$output" | jq -e '.entries[0].source'
  echo "$output" | jq -e '.entries[0].status'
}

@test "output includes danger, unreviewed, reviewed counts" {
  cat > "$FIXTURE/settings.json" <<'EOF'
{
  "permissions": {
    "allow": ["Bash(git status:*)", "Bash(ls:*)"]
  }
}
EOF

  run bash "$SCRIPT" check --settings-dir "$FIXTURE"
  echo "$output" | jq -e 'has("danger")'
  echo "$output" | jq -e 'has("unreviewed")'
  echo "$output" | jq -e 'has("reviewed")'
}

@test "parses both allow and deny entries" {
  cat > "$FIXTURE/settings.json" <<'EOF'
{
  "permissions": {
    "allow": ["Bash(git status:*)"],
    "deny": ["Bash(rm -rf /)*"]
  }
}
EOF

  run bash "$SCRIPT" check --settings-dir "$FIXTURE"
  echo "$output" | jq -e '.entries | length == 2'
}

@test "missing settings.json exits with error" {
  run bash "$SCRIPT" check --settings-dir "$FIXTURE"
  [ "$status" -eq 2 ]
}


# =========================================================================
# Step 2: Dual-file parsing + deduplication (AC-1 complete, AC-10)
# =========================================================================

@test "parses entries from both settings files" {
  cat > "$FIXTURE/settings.json" <<'EOF'
{
  "permissions": {
    "allow": ["Bash(git status:*)"]
  }
}
EOF
  cat > "$FIXTURE/settings.local.json" <<'EOF'
{
  "permissions": {
    "allow": ["Bash(echo:*)"]
  }
}
EOF

  run bash "$SCRIPT" check --settings-dir "$FIXTURE"
  echo "$output" | jq -e '.entries | length == 2'
}

@test "duplicate entry in both files reports single entry with array source" {
  cat > "$FIXTURE/settings.json" <<'EOF'
{
  "permissions": {
    "allow": ["Bash(bats:*)"]
  }
}
EOF
  cat > "$FIXTURE/settings.local.json" <<'EOF'
{
  "permissions": {
    "allow": ["Bash(bats:*)"]
  }
}
EOF

  run bash "$SCRIPT" check --settings-dir "$FIXTURE"
  echo "$output" | jq -e '.entries | length == 1'
  echo "$output" | jq -e '.entries[0].source == ["settings.json", "settings.local.json"]'
}

@test "unique entries report single source as array" {
  cat > "$FIXTURE/settings.json" <<'EOF'
{
  "permissions": {
    "allow": ["Bash(git status:*)"]
  }
}
EOF

  run bash "$SCRIPT" check --settings-dir "$FIXTURE"
  echo "$output" | jq -e '.entries[0].source == ["settings.json"]'
}

@test "missing settings.local.json is not an error" {
  cat > "$FIXTURE/settings.json" <<'EOF'
{
  "permissions": {
    "allow": ["Bash(ls:*)"]
  }
}
EOF

  run bash "$SCRIPT" check --settings-dir "$FIXTURE"
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
  echo "$output" | jq -e '.entries | length == 1'
}


# =========================================================================
# Step 3: Dangerous pattern detection (AC-3)
# =========================================================================

@test "broad wildcard flagged as DANGER" {
  cat > "$FIXTURE/settings.json" <<'EOF'
{
  "permissions": {
    "allow": ["Bash(echo:*)", "Bash(cat:*)", "Bash(find:*)", "Bash(bash:*)"]
  }
}
EOF

  run bash "$SCRIPT" check --settings-dir "$FIXTURE"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.danger == 4'
  echo "$output" | jq -e '[.entries[] | select(.status == "DANGER")] | length == 4'
}

@test "compound operators flagged as DANGER" {
  cat > "$FIXTURE/settings.json" <<'EOF'
{
  "permissions": {
    "allow": [
      "Bash(bash -n scripts/foo.sh && echo \"ok\")",
      "Bash(cmd1; cmd2)"
    ]
  }
}
EOF

  run bash "$SCRIPT" check --settings-dir "$FIXTURE"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.danger == 2'
}

@test "env-prefix command flagged as DANGER" {
  cat > "$FIXTURE/settings.json" <<'EOF'
{
  "permissions": {
    "allow": ["Bash(FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch)"]
  }
}
EOF

  run bash "$SCRIPT" check --settings-dir "$FIXTURE"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.entries[0].status == "DANGER"'
}

@test "redirect operators flagged as DANGER" {
  cat > "$FIXTURE/settings.json" <<'EOF'
{
  "permissions": {
    "allow": ["Bash(echo foo > file.txt)", "Bash(echo bar >> file.txt)"]
  }
}
EOF

  run bash "$SCRIPT" check --settings-dir "$FIXTURE"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.danger == 2'
}

@test "find -exec and find -delete flagged as DANGER" {
  cat > "$FIXTURE/settings.json" <<'EOF'
{
  "permissions": {
    "allow": ["Bash(find . -exec rm {} \\;)", "Bash(find . -delete)"]
  }
}
EOF

  run bash "$SCRIPT" check --settings-dir "$FIXTURE"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.danger == 2'
}

@test "loop primitives flagged as DANGER" {
  cat > "$FIXTURE/settings.json" <<'EOF'
{
  "permissions": {
    "allow": ["Bash(for f:*)", "Bash(do echo:*)", "Bash(done)"]
  }
}
EOF

  run bash "$SCRIPT" check --settings-dir "$FIXTURE"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.danger == 3'
}

@test "file mutation commands flagged as DANGER" {
  cat > "$FIXTURE/settings.json" <<'EOF'
{
  "permissions": {
    "allow": ["Bash(sort -o file.txt)", "Bash(git branch -D main)", "Bash(git tag -d v1)"]
  }
}
EOF

  run bash "$SCRIPT" check --settings-dir "$FIXTURE"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.danger == 3'
}

@test "arbitrary execution flagged as DANGER" {
  cat > "$FIXTURE/settings.json" <<'EOF'
{
  "permissions": {
    "allow": ["Bash(xargs -I {} cat {})", "Bash(env PATH=/tmp cmd)"]
  }
}
EOF

  run bash "$SCRIPT" check --settings-dir "$FIXTURE"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.danger == 2'
}

@test "safe entries not flagged as DANGER" {
  cat > "$FIXTURE/settings.json" <<'EOF'
{
  "permissions": {
    "allow": ["Bash(git status:*)", "Bash(ls:*)", "Bash(bats:*)", "Bash(bash -n scripts/foo.sh)"]
  }
}
EOF

  run bash "$SCRIPT" check --settings-dir "$FIXTURE"
  echo "$output" | jq -e '.danger == 0'
}

@test "DANGER entry includes matched pattern name" {
  cat > "$FIXTURE/settings.json" <<'EOF'
{
  "permissions": {
    "allow": ["Bash(echo:*)"]
  }
}
EOF

  run bash "$SCRIPT" check --settings-dir "$FIXTURE"
  echo "$output" | jq -e '.entries[0].matched_pattern'
}
