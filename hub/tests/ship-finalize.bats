#!/usr/bin/env bats
# BTS-235: ship-finalize substrate — collapse the post-/pr ship-finalization
# sequence (title-fix → ready → merge → land → ticket-close) into one verb.
#
# Tests exercise the substrate via stubbed gh (GH_OVERRIDE) and stubbed
# linear-query.sh (operations.sh routes through it). Full-pipeline integration
# (cmd_land's branch-recovery from squash-merge subjects, real-API ticket
# transition) is dogfood-validated on the BTS-235 ship itself.

bats_require_minimum_version 1.5.0

REPO_ROOT="$BATS_TEST_DIRNAME/../.."
SCRIPT="$REPO_ROOT/.ccanvil/scripts/docs-check.sh"
SHIP_SKILL="$REPO_ROOT/.claude/skills/ship/SKILL.md"

setup() {
  TMPDIR_BATS=$(mktemp -d)
}

teardown() {
  [[ -n "${TMPDIR_BATS:-}" ]] && rm -rf "$TMPDIR_BATS"
}

# Build a stubbed gh CLI. State_file controls per-call responses; each
# invocation appends its argv to LOG. Default behavior:
#   - `gh pr view <N> --json state` → emit {"state":"OPEN"}
#   - `gh pr view <N> --json title` → emit "feat(default): placeholder"
#   - `gh pr edit <N>` → success, no output
#   - `gh pr ready <N>` → success
#   - `gh pr merge <N>` → success
write_gh_stub() {
  local stub="$TMPDIR_BATS/gh-stub.sh"
  cat > "$stub" <<'STUBEOF'
#!/usr/bin/env bash
# argv: pr view <N> --json state OR pr ready <N> OR pr merge <N> ... etc.
echo "$@" >> "$GH_STUB_LOG"
# Read directives from $GH_STUB_DIRECTIVES (one per line: <pattern>:<exit>:<output>)
if [[ -f "$GH_STUB_DIRECTIVES" ]]; then
  while IFS=$'\t' read -r pattern exit_code output; do
    if [[ "$*" == *$pattern* ]]; then
      [[ -n "$output" ]] && printf '%s' "$output"
      exit "$exit_code"
    fi
  done < "$GH_STUB_DIRECTIVES"
fi
# Default: success with empty output
exit 0
STUBEOF
  chmod +x "$stub"
  echo "$stub"
}

# =========================================================================
# AC-1: missing PR number → exit 2 with usage
# =========================================================================

@test "AC-1: missing PR number exits 2 with usage" {
  run bash "$SCRIPT" ship-finalize --project-dir "$TMPDIR_BATS"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "Usage: docs-check.sh ship-finalize"
}

# =========================================================================
# AC-2: PR already MERGED → idempotent no-op, exit 0
# =========================================================================

@test "AC-2: already-MERGED PR returns idempotent success" {
  set -e
  stub=$(write_gh_stub)
  export GH_STUB_LOG="$TMPDIR_BATS/gh-log"
  export GH_STUB_DIRECTIVES="$TMPDIR_BATS/gh-directives"
  : > "$GH_STUB_LOG"
  printf 'pr view\t0\tMERGED\n' > "$GH_STUB_DIRECTIVES"

  GH_OVERRIDE="$stub" run bash "$SCRIPT" ship-finalize --project-dir "$TMPDIR_BATS" 999
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.pr_merged == true'
  echo "$output" | jq -e '.note == "already merged"'
  # Only the pre-flight gh pr view should have been called
  [ "$(wc -l < "$GH_STUB_LOG" | tr -d ' ')" = "1" ]
}

# =========================================================================
# AC-2: pre-flight gh failure → exit 1 with step:"preflight"
# =========================================================================

@test "AC-2: pre-flight gh failure exits 1 with preflight error" {
  stub=$(write_gh_stub)
  export GH_STUB_LOG="$TMPDIR_BATS/gh-log"
  export GH_STUB_DIRECTIVES="$TMPDIR_BATS/gh-directives"
  : > "$GH_STUB_LOG"
  printf 'pr view\t1\tno such PR\n' > "$GH_STUB_DIRECTIVES"

  GH_OVERRIDE="$stub" run bash "$SCRIPT" ship-finalize --project-dir "$TMPDIR_BATS" 999
  [ "$status" -eq 1 ]
  echo "$output" | jq -e '.step == "preflight"'
  echo "$output" | jq -e '.errors | length > 0'
}

# =========================================================================
# AC-7: output JSON schema present in all branches
# =========================================================================

@test "AC-7: JSON output schema has expected keys on idempotent success" {
  set -e
  stub=$(write_gh_stub)
  export GH_STUB_LOG="$TMPDIR_BATS/gh-log"
  export GH_STUB_DIRECTIVES="$TMPDIR_BATS/gh-directives"
  printf 'pr view\t0\tMERGED\n' > "$GH_STUB_DIRECTIVES"

  GH_OVERRIDE="$stub" run bash "$SCRIPT" ship-finalize --project-dir "$TMPDIR_BATS" 555
  [ "$status" -eq 0 ]
  # All required keys present
  echo "$output" | jq -e '.pr != null'
  echo "$output" | jq -e 'has("pr_merged")'
  echo "$output" | jq -e 'has("branch_deleted")'
  echo "$output" | jq -e 'has("title_result")'
  echo "$output" | jq -e 'has("ticket_closed")'
  echo "$output" | jq -e 'has("errors")'
}

# =========================================================================
# Drift-guard: BTS-235 referenced inline in docs-check.sh
# =========================================================================

@test "drift: BTS-235 referenced inline in docs-check.sh" {
  grep -q "BTS-235" "$SCRIPT"
}

# =========================================================================
# AC-8: /ship skill exists and references the substrate
# =========================================================================

@test "AC-8 lock: /ship skill file exists" {
  [ -f "$SHIP_SKILL" ]
}

@test "AC-8 lock: /ship skill calls ship-finalize substrate" {
  [ -f "$SHIP_SKILL" ] && grep -q "ship-finalize" "$SHIP_SKILL"
}
