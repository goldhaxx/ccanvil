#!/usr/bin/env bats
# Tests for scripts/manifest-check.sh
#
# Each test creates isolated temp directories with mock README and files.

SCRIPT="$BATS_TEST_DIRNAME/../scripts/manifest-check.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  REPO=$(mktemp -d)
  cd "$REPO"
  git init -q
}

teardown() {
  rm -rf "$REPO"
}


# =========================================================================
# Step 1: Parse README manifest tables
# =========================================================================

@test "parse extracts path and description from a 4-column table" {
  cat > "$REPO/README.md" <<'EOF'
# Project

## Manifest

| File | Copy to | What it does | Customize? |
|---|---|---|---|
| `CLAUDE.md` | `./CLAUDE.md` | The core config file. | Yes. |
| `.claudeignore` | `./.claudeignore` | Tells Claude which files to skip. | Yes. |
EOF

  run bash "$SCRIPT" parse "$REPO/README.md"
  [ "$status" -eq 0 ]
  # Should output JSON array of {path, description} objects
  echo "$output" | jq -e 'length == 2'
  echo "$output" | jq -e '.[0].path == "CLAUDE.md"'
  echo "$output" | jq -e '.[0].description == "The core config file."'
  echo "$output" | jq -e '.[1].path == ".claudeignore"'
  echo "$output" | jq -e '.[1].description == "Tells Claude which files to skip."'
}

@test "parse extracts path and description from a 3-column table" {
  cat > "$REPO/README.md" <<'EOF'
## Reference

| File in zip | What to do with it | What it does |
|---|---|---|
| `README.md` | Keep for reference. | Setup guide and file manifest. |
EOF

  run bash "$SCRIPT" parse "$REPO/README.md"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'length == 1'
  echo "$output" | jq -e '.[0].path == "README.md"'
  echo "$output" | jq -e '.[0].description == "Setup guide and file manifest."'
}

@test "parse skips header and separator rows" {
  cat > "$REPO/README.md" <<'EOF'
| File | Copy to | What it does | Customize? |
|---|---|---|---|
| `foo.md` | `./foo.md` | Does foo things. | No. |
EOF

  run bash "$SCRIPT" parse "$REPO/README.md"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'length == 1'
}

@test "parse handles multiple tables in one file" {
  cat > "$REPO/README.md" <<'EOF'
## Section A

| File | Copy to | What it does | Customize? |
|---|---|---|---|
| `a.md` | `./a.md` | File A. | No. |

## Section B

| File | Copy to | What it does | Customize? |
|---|---|---|---|
| `b.md` | `./b.md` | File B. | Yes. |
EOF

  run bash "$SCRIPT" parse "$REPO/README.md"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'length == 2'
  echo "$output" | jq -e '.[0].path == "a.md"'
  echo "$output" | jq -e '.[1].path == "b.md"'
}

@test "parse strips backticks from paths" {
  cat > "$REPO/README.md" <<'EOF'
| File | Copy to | What it does | Customize? |
|---|---|---|---|
| `scripts/foo.sh` | `./scripts/foo.sh` | Runs foo. | No. |
EOF

  run bash "$SCRIPT" parse "$REPO/README.md"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[0].path == "scripts/foo.sh"'
}

@test "parse works on the real README" {
  run bash "$SCRIPT" parse "$BATS_TEST_DIRNAME/../README.md"
  [ "$status" -eq 0 ]
  # The real README has at least 30 entries across all tables
  count=$(echo "$output" | jq 'length')
  [ "$count" -ge 30 ]
}

@test "parse fails with clear error when file not found" {
  run bash "$SCRIPT" parse "/nonexistent/README.md"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "not found\|no such file\|does not exist"
}


# =========================================================================
# Step 2: File existence + untracked file discovery
# =========================================================================

@test "check-existence reports existing files as found" {
  mkdir -p "$REPO/.claude/rules" "$REPO/scripts"
  echo "# TDD" > "$REPO/.claude/rules/tdd.md"
  echo "#!/bin/bash" > "$REPO/scripts/sync.sh"

  # Create a manifest with these paths
  cat > "$REPO/README.md" <<'EOF'
| File | Copy to | What it does | Customize? |
|---|---|---|---|
| `.claude/rules/tdd.md` | `./.claude/rules/tdd.md` | TDD rules. | No. |
| `scripts/sync.sh` | `./scripts/sync.sh` | Sync script. | No. |
EOF

  run bash "$SCRIPT" check-existence "$REPO/README.md"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.found | length == 2'
  echo "$output" | jq -e '.missing_from_disk | length == 0'
}

@test "check-existence reports missing files" {
  # Create a manifest with paths that don't exist on disk
  cat > "$REPO/README.md" <<'EOF'
| File | Copy to | What it does | Customize? |
|---|---|---|---|
| `.claude/rules/tdd.md` | `./.claude/rules/tdd.md` | TDD rules. | No. |
| `scripts/gone.sh` | `./scripts/gone.sh` | Missing script. | No. |
EOF

  mkdir -p "$REPO/.claude/rules"
  echo "# TDD" > "$REPO/.claude/rules/tdd.md"

  run bash "$SCRIPT" check-existence "$REPO/README.md"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.found | length == 1'
  echo "$output" | jq -e '.missing_from_disk | length == 1'
  echo "$output" | jq -e '.missing_from_disk[0].path == "scripts/gone.sh"'
}

@test "check-existence discovers untracked files in tracked directories" {
  mkdir -p "$REPO/.claude/rules" "$REPO/scripts"
  echo "# TDD" > "$REPO/.claude/rules/tdd.md"
  echo "# Extra" > "$REPO/.claude/rules/extra.md"
  echo "#!/bin/bash" > "$REPO/scripts/sync.sh"

  # Manifest only has tdd.md and sync.sh — extra.md is untracked
  cat > "$REPO/README.md" <<'EOF'
| File | Copy to | What it does | Customize? |
|---|---|---|---|
| `.claude/rules/tdd.md` | `./.claude/rules/tdd.md` | TDD rules. | No. |
| `scripts/sync.sh` | `./scripts/sync.sh` | Sync script. | No. |
EOF

  run bash "$SCRIPT" check-existence "$REPO/README.md"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.missing_from_manifest | length == 1'
  echo "$output" | jq -e '.missing_from_manifest[0].path == ".claude/rules/extra.md"'
}

@test "check-existence ignores files outside tracked directories" {
  mkdir -p "$REPO/.claude/rules"
  echo "# TDD" > "$REPO/.claude/rules/tdd.md"
  echo "random" > "$REPO/random.txt"

  cat > "$REPO/README.md" <<'EOF'
| File | Copy to | What it does | Customize? |
|---|---|---|---|
| `.claude/rules/tdd.md` | `./.claude/rules/tdd.md` | TDD rules. | No. |
EOF

  run bash "$SCRIPT" check-existence "$REPO/README.md"
  [ "$status" -eq 0 ]
  # random.txt is outside tracked dirs, should not appear
  echo "$output" | jq -e '.missing_from_manifest | length == 0'
}

@test "check-existence works on real README against real repo" {
  cd "$BATS_TEST_DIRNAME/.."
  run bash "$SCRIPT" check-existence README.md
  [ "$status" -eq 0 ]
  # All found entries should be real files
  found=$(echo "$output" | jq '.found | length')
  [ "$found" -gt 0 ]
  # Missing from disk should be zero or very few (reference files not in project)
  missing=$(echo "$output" | jq '.missing_from_disk | length')
  [ "$missing" -lt 10 ]
}
