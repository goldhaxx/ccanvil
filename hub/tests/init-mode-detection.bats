#!/usr/bin/env bats

# BTS-497 telemetry hooks.
source "$BATS_TEST_DIRNAME/_helpers/telemetry.bash"
setup_file()    { telemetry_setup_file; }
teardown_file() { telemetry_teardown_file; }
# Tests for project-mode detection in ccanvil-sync.sh init-preflight.
#
# Mode detection classifies the target directory into one of five modes
# before /ccanvil-init runs, so the skill can branch on the right defaults:
#   fresh, source-no-git, mature-repo, partial-ccanvil, already-initialized
#
# The hub used by these tests is the real ccanvil repo — mode detection
# only reads the NODE directory, so hub contents don't affect outcomes.

HUB_ROOT="$BATS_TEST_DIRNAME/../.."
SCRIPT="$HUB_ROOT/.ccanvil/scripts/ccanvil-sync.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  NODE=$(mktemp -d)
  mkdir -p "$NODE/.ccanvil/scripts"
  cp "$SCRIPT" "$NODE/.ccanvil/scripts/ccanvil-sync.sh"
  cd "$NODE"
  telemetry_setup
}

teardown() {
  telemetry_teardown
  rm -rf "$NODE"
}

# Helper: run init-preflight and extract project_mode
_mode() {
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-preflight "$HUB_ROOT" | jq -r '.project_mode'
}

# =========================================================================
# AC-1, AC-2, AC-3: the five modes
# =========================================================================

@test "mode-detection: fresh — bootstrapped script only, nothing else" {
  # NODE has only .ccanvil/scripts/ccanvil-sync.sh (the bootstrap).
  # No .git/, no source files, no .claude/, no CLAUDE.md, no lockfile.
  local mode
  mode=$(_mode)
  [ "$mode" = "fresh" ]
}

@test "mode-detection: source-no-git — has source file, no .git/" {
  # Simulate a codebase that was never put under git.
  cat > "$NODE/README.md" <<'EOF'
# My Project
Some source code.
EOF
  mkdir -p "$NODE/src"
  echo "console.log('hi');" > "$NODE/src/index.js"

  local mode
  mode=$(_mode)
  [ "$mode" = "source-no-git" ]
}

@test "mode-detection: mature-repo — .git/, real commits, no ccanvil markers" {
  # Simulate an established repo with history and no ccanvil artifacts yet.
  git -C "$NODE" init -q -b main
  echo "# Established Project" > "$NODE/README.md"
  mkdir -p "$NODE/src"
  echo "print('hi')" > "$NODE/src/app.py"
  git -C "$NODE" add -A
  git -C "$NODE" -c user.email=t@t -c user.name=t commit -q -m "initial commit"

  local mode
  mode=$(_mode)
  [ "$mode" = "mature-repo" ]
}

@test "mode-detection: partial-ccanvil — has .claude/ but no lockfile" {
  # Simulate a project that was partway through a ccanvil init (or hand-assembled).
  mkdir -p "$NODE/.claude/rules"
  echo "# some rule" > "$NODE/.claude/rules/example.md"
  # No .ccanvil/ccanvil.lock → not already-initialized.

  local mode
  mode=$(_mode)
  [ "$mode" = "partial-ccanvil" ]
}

@test "mode-detection: partial-ccanvil — has CLAUDE.md but no lockfile" {
  echo "# Custom project notes" > "$NODE/CLAUDE.md"

  local mode
  mode=$(_mode)
  [ "$mode" = "partial-ccanvil" ]
}

@test "mode-detection: already-initialized — has ccanvil.lock + sync script" {
  # Create a minimal lockfile alongside the bootstrapped script.
  echo '{"hub_version": "abc", "files": {}}' > "$NODE/.ccanvil/ccanvil.lock"

  local mode
  mode=$(_mode)
  [ "$mode" = "already-initialized" ]
}

# =========================================================================
# AC-24: bare git repo (no commits) → source-no-git (override mature-repo)
# =========================================================================

@test "mode-detection: AC-24 edge — .git/ without commits classifies as source-no-git" {
  git -C "$NODE" init -q -b main
  # Source file staged but NOT committed — HEAD does not exist yet.
  echo "# draft" > "$NODE/README.md"

  local mode
  mode=$(_mode)
  [ "$mode" = "source-no-git" ]
}

# =========================================================================
# AC-26: mature repo with no source files (history is the signal)
# =========================================================================

@test "mode-detection: AC-26 edge — .git/ with commits but no source files is mature-repo" {
  # A repo initialized and committed (maybe an empty README was deleted later).
  git -C "$NODE" init -q -b main
  echo "placeholder" > "$NODE/x"
  git -C "$NODE" add -A
  git -C "$NODE" -c user.email=t@t -c user.name=t commit -q -m "initial"
  rm -f "$NODE/x"
  git -C "$NODE" add -A
  git -C "$NODE" -c user.email=t@t -c user.name=t commit -q -m "clear" 2>/dev/null || true

  local mode
  mode=$(_mode)
  [ "$mode" = "mature-repo" ]
}

# =========================================================================
# AC-3: detection is pure — reads filesystem only, writes nothing
# =========================================================================

@test "mode-detection: AC-3 — detection writes nothing to the node" {
  # Seed a mature-repo fixture.
  git -C "$NODE" init -q -b main
  echo "# proj" > "$NODE/README.md"
  git -C "$NODE" add -A
  git -C "$NODE" -c user.email=t@t -c user.name=t commit -q -m "initial"

  # Snapshot before.
  local before
  before=$(find "$NODE" -type f -not -path '*/.git/*' | sort | xargs shasum | shasum)

  # Run preflight twice.
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-preflight "$HUB_ROOT" >/dev/null
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-preflight "$HUB_ROOT" >/dev/null

  # Snapshot after — must match before.
  local after
  after=$(find "$NODE" -type f -not -path '*/.git/*' | sort | xargs shasum | shasum)

  [ "$before" = "$after" ]
}

# =========================================================================
# Output shape: project_mode is a top-level field alongside plan/summary
# =========================================================================

@test "mode-detection: project_mode is a top-level field in init-preflight output" {
  set -e
  run bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-preflight "$HUB_ROOT"
  [ "$status" -eq 0 ]

  # jq -e returns nonzero if the field is missing or null.
  echo "$output" | jq -e '.project_mode' >/dev/null
  echo "$output" | jq -e '.plan' >/dev/null
  echo "$output" | jq -e '.summary' >/dev/null
}
