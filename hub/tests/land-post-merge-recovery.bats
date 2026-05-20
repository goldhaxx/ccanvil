#!/usr/bin/env bats
# BTS-138 — cmd_land on main recovers the landed feature branch from the last
# squash-merge commit's (#<PR>) suffix via `gh pr view`, then delegates to the
# existing cmd_auto_close_emit. Fixes the 3rd-consecutive-stasis determinism
# review gap where `gh pr merge --delete-branch` leaves /land on main without
# emitting the AUTO-CLOSE: marker.

bats_require_minimum_version 1.5.0

# BTS-497 telemetry hooks.
source "$BATS_TEST_DIRNAME/_helpers/telemetry.bash"
setup_file()    { telemetry_setup_file; }
teardown_file() { telemetry_teardown_file; }

DOCS="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/docs-check.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  PROJECT=$(mktemp -d)
  mkdir -p "$PROJECT/docs/specs" "$PROJECT/.bin"
  cd "$PROJECT"
  git init -q -b main .
  git config user.email "test@example.com"
  git config user.name "test"
  git config commit.gpgsign false
  # Seed a baseline commit so HEAD~1 exists in the "stasis at HEAD" tests.
  git commit -q --allow-empty -m "init"
  telemetry_setup
}

teardown() {
  telemetry_teardown
  rm -rf "$PROJECT"
}

# --- fixtures ---------------------------------------------------------------

_seed_spec_linear() {
  local id="$1" slug="$2"
  cat > "$PROJECT/docs/specs/$slug.md" <<MD
# Feature: Fixture
> Feature: $slug
> Work: linear:$id
> Created: 1777004190
> Status: Complete
MD
}

_seed_spec_local() {
  local uid="$1" slug="$2"
  cat > "$PROJECT/docs/specs/$slug.md" <<MD
# Feature: Fixture
> Feature: $slug
> Work: local:$uid
> Created: 1777004190
> Status: Complete
MD
}

# Install a `gh` shim that handles `pr view <N> --json headRefName -q
# .headRefName`. Branch name read from $FAKE_HEAD_REF; exit $FAKE_GH_EXIT.
_install_gh_shim() {
  cat > "$PROJECT/.bin/gh" <<'SH'
#!/usr/bin/env bash
if [[ "${FAKE_GH_EXIT:-0}" -ne 0 ]]; then
  exit "$FAKE_GH_EXIT"
fi
# Only handle `gh pr view <N> --json headRefName -q .headRefName`
if [[ "$1" == "pr" && "$2" == "view" ]]; then
  printf '%s\n' "${FAKE_HEAD_REF:-}"
  exit 0
fi
exit 0
SH
  chmod +x "$PROJECT/.bin/gh"
}

# ===========================================================================
# Helper: cmd_land_recover_branch (subcommand: land-recover-branch)
# Pure-ish: inspects current repo HEAD's last-commit subject, parses
# (#<N>), queries gh, echoes the recovered branch or empty. Testable in
# isolation.
# ===========================================================================

@test "BTS-138 AC-1 helper: HEAD subject with (#54), gh returns claude/feat/foo → echoes claude/feat/foo" {
  set -e
  _install_gh_shim
  export FAKE_HEAD_REF="claude/feat/bts-138-land-post-merge-branch-recovery"
  git commit -q --allow-empty -m "feat(bts-138): ship the fix (#54)"
  PATH="$PROJECT/.bin:$PATH" run bash "$DOCS" land-recover-branch
  [ "$status" -eq 0 ]
  [ "$output" = "claude/feat/bts-138-land-post-merge-branch-recovery" ]
}

@test "BTS-138 AC-2 helper: HEAD = docs: stasis, HEAD~1 = squash-merge → recovery reads HEAD~1" {
  set -e
  _install_gh_shim
  export FAKE_HEAD_REF="claude/feat/bts-138-land-post-merge-branch-recovery"
  git commit -q --allow-empty -m "feat(bts-138): ship the fix (#54)"
  git commit -q --allow-empty -m "docs: stasis session-2026-04-24"
  PATH="$PROJECT/.bin:$PATH" run bash "$DOCS" land-recover-branch
  [ "$status" -eq 0 ]
  [ "$output" = "claude/feat/bts-138-land-post-merge-branch-recovery" ]
}

@test "BTS-138 AC-3: HEAD has no (#N) suffix → stderr WARN, empty stdout, exit 0" {
  _install_gh_shim
  git commit -q --allow-empty -m "direct commit to main"
  PATH="$PROJECT/.bin:$PATH" run --separate-stderr bash "$DOCS" land-recover-branch
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [[ "$stderr" =~ "WARN: land on main — could not recover PR number" ]]
}

@test "BTS-138 AC-4: gh exits nonzero (offline / 404) → stderr WARN, empty stdout, exit 0" {
  _install_gh_shim
  export FAKE_GH_EXIT=1
  git commit -q --allow-empty -m "feat(bts-138): ship the fix (#54)"
  PATH="$PROJECT/.bin:$PATH" run --separate-stderr bash "$DOCS" land-recover-branch
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [[ "$stderr" =~ "WARN: land on main — could not recover landed branch via gh" ]]
}

@test "BTS-138 AC-4: gh returns empty headRefName → stderr WARN, empty stdout, exit 0" {
  _install_gh_shim
  export FAKE_HEAD_REF=""
  git commit -q --allow-empty -m "feat(bts-138): ship the fix (#54)"
  PATH="$PROJECT/.bin:$PATH" run --separate-stderr bash "$DOCS" land-recover-branch
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [[ "$stderr" =~ "WARN: land on main — could not recover landed branch via gh" ]]
}

@test "BTS-138 AC-8: gh not on PATH → stderr WARN, empty stdout, exit 0" {
  # Do NOT install the shim. Set PATH to include only shell basics (no
  # /opt/homebrew, no /usr/local/bin, no pre-existing .bin entries) so `gh`
  # cannot be found. bats teardown still has access to mktemp/rm/etc.
  git commit -q --allow-empty -m "feat(bts-138): ship the fix (#54)"
  PATH="$PROJECT/.bin:/usr/bin:/bin" run --separate-stderr bash "$DOCS" land-recover-branch
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [[ "$stderr" =~ "WARN: land on main — gh unavailable" ]]
}

@test "BTS-138 AC-2 edge: HEAD is stasis, HEAD~1 has no (#N) → WARN, empty stdout, exit 0" {
  _install_gh_shim
  git commit -q --allow-empty -m "chore: baseline"
  git commit -q --allow-empty -m "docs: stasis session-2026-04-24"
  PATH="$PROJECT/.bin:$PATH" run --separate-stderr bash "$DOCS" land-recover-branch
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [[ "$stderr" =~ "WARN: land on main — could not recover PR number" ]]
}

# ===========================================================================
# Integration: cmd_land on main (branch == main) exercises the full chain.
# We prevent the "normal" main-path side effects by not setting up any origin
# remote — git fetch/reset steps become no-ops.
# ===========================================================================

@test "BTS-138 AC-1 integration: land on main with recoverable squash-merge → AUTO-CLOSE emitted" {
  set -e
  _install_gh_shim
  _seed_spec_linear "BTS-138" "bts-138-land-post-merge-branch-recovery"
  export FAKE_HEAD_REF="claude/feat/bts-138-land-post-merge-branch-recovery"
  git commit -q --allow-empty -m "feat(bts-138): ship the fix (#54)"
  PATH="$PROJECT/.bin:$PATH" run bash "$DOCS" land
  [ "$status" -eq 0 ]
  [[ "$output" =~ "AUTO-CLOSE: " ]]
  echo "$output" | grep "^AUTO-CLOSE: " | sed 's/^AUTO-CLOSE: //' | \
    jq -e '.provider == "linear" and .id == "BTS-138" and .role == "done"'
}

@test "BTS-138 AC-5 integration: land on main recovers non-claude branch → no AUTO-CLOSE (delegates to existing skip)" {
  set -e
  _install_gh_shim
  export FAKE_HEAD_REF="hotfix/urgent"
  git commit -q --allow-empty -m "feat: hotfix (#99)"
  PATH="$PROJECT/.bin:$PATH" run bash "$DOCS" land
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "AUTO-CLOSE: " ]]
  [[ "$output" =~ "no feature-id detected" ]]
}

@test "BTS-138 AC-6 integration: land on main recovers local-provider branch → logged skip, no AUTO-CLOSE" {
  set -e
  _install_gh_shim
  _seed_spec_local "idea-999" "local-idea-999"
  export FAKE_HEAD_REF="claude/feat/local-idea-999"
  git commit -q --allow-empty -m "feat(local): local provider ship (#100)"
  PATH="$PROJECT/.bin:$PATH" run bash "$DOCS" land
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "AUTO-CLOSE: " ]]
  [[ "$output" =~ "local provider" ]]
}

@test "BTS-138 AC-3 integration: land on main with no PR suffix → no AUTO-CLOSE, no crash" {
  set -e
  _install_gh_shim
  git commit -q --allow-empty -m "direct commit to main"
  PATH="$PROJECT/.bin:$PATH" run --separate-stderr bash "$DOCS" land
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "AUTO-CLOSE: " ]]
  [[ "$stderr" =~ "WARN: land on main — could not recover PR number" ]]
}

# ===========================================================================
# AC-10 (docs)
# ===========================================================================

@test "BTS-138 AC-10: command-reference.md documents the post-merge-on-main recovery" {
  # Match the BTS-138 specific addition. The row already mentioned "post-merge"
  # for BTS-119 + "(post-`gh pr merge --delete-branch`)" for the fast-forward
  # behavior, so we require the distinctive new-behavior phrase describing
  # RECOVERY of the landed branch.
  local ref="$BATS_TEST_DIRNAME/../../.ccanvil/guide/command-reference.md"
  grep -qE "recover.*landed branch|BTS-138" "$ref"
}
