#!/usr/bin/env bats
# Tests for broadcast bootstrap tolerance of gitignored lockfiles.
#
# Historical context: this file previously tested commit_hub_file and
# hub-side chore(registry) commits. Those responsibilities were removed by
# the registry-local-state spec — registry.json is now gitignored local
# state; register/broadcast append to .ccanvil/events.log instead of
# committing. Those assertions live in hub/tests/registry-local-state.bats.
# The remaining test here concerns a separate bootstrap edge case.

SCRIPT="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/ccanvil-sync.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  HUB=$(mktemp -d)
  NODE=$(mktemp -d)

  mkdir -p "$HUB/.claude/rules"
  mkdir -p "$HUB/.ccanvil/scripts"
  cp "$SCRIPT" "$HUB/.ccanvil/scripts/ccanvil-sync.sh"

  cat > "$HUB/.claude/rules/tdd.md" <<'HUBEOF'
# TDD Rules
<!-- NODE-SPECIFIC-START -->
HUBEOF

  cat > "$HUB/.gitignore" <<'HUBEOF'
.DS_Store
.ccanvil/registry.json
.ccanvil/events.log
HUBEOF

  git -C "$HUB" init -q
  git -C "$HUB" -c user.email=test@test.com -c user.name=test add -A
  git -C "$HUB" -c user.email=test@test.com -c user.name=test commit -q -m "init"

  cp -R "$HUB/.claude" "$NODE/.claude"
  mkdir -p "$NODE/.ccanvil/scripts"
  cp "$SCRIPT" "$NODE/.ccanvil/scripts/ccanvil-sync.sh"

  git -C "$NODE" init -q
  git -C "$NODE" -c user.email=test@test.com -c user.name=test add -A
  git -C "$NODE" -c user.email=test@test.com -c user.name=test commit -q -m "init node"
}

teardown() {
  rm -rf "$HUB" "$NODE"
}

git_commit_in() {
  local dir="$1"; shift
  (cd "$dir" && ALLOW_MAIN=1 git -c user.email=test@test.com -c user.name=test -c commit.gpgsign=false "$@")
}

@test "broadcast bootstrap: doesn't error when lockfile is gitignored" {
  git -C "$HUB" config user.email test@test.com
  git -C "$HUB" config user.name test

  cd "$NODE"
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init "$HUB"

  # Add lockfile to node's gitignore
  echo ".ccanvil/ccanvil.lock" >> "$NODE/.gitignore"
  git -C "$NODE" rm --cached .ccanvil/ccanvil.lock 2>/dev/null || true
  git_commit_in "$NODE" add -A
  git_commit_in "$NODE" commit -q -m "gitignore lockfile" 2>/dev/null || true

  # Confirm lockfile is actually gitignored now
  (cd "$NODE" && git check-ignore -q .ccanvil/ccanvil.lock)

  # Update the hub sync script so pre-check will bootstrap
  echo "# hub-side comment update" >> "$HUB/.ccanvil/scripts/ccanvil-sync.sh"
  git_commit_in "$HUB" add .ccanvil/scripts/ccanvil-sync.sh
  git_commit_in "$HUB" commit -q -m "update hub sync script"

  # Broadcast — bootstrap should NOT fail due to "paths ignored" error
  run bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" broadcast
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -qi "ignored by"
}
