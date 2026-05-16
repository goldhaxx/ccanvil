#!/usr/bin/env bats
# BTS-178 — assert-pr-title substrate primitive.
#
# Reads live PR title via gh pr view, computes expected from spec, and
# force-updates via gh pr edit when the title is placeholder-shaped or
# missing the feat(<feature-id>): prefix. Wires into /pr.

bats_require_minimum_version 1.5.0

# BTS-497 telemetry hooks.
source "$BATS_TEST_DIRNAME/_helpers/telemetry.bash"
setup_file()    { telemetry_setup_file; }
teardown_file() { telemetry_teardown_file; }

SCRIPT="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/docs-check.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  PROJECT=$(mktemp -d)
  mkdir -p "$PROJECT/docs" "$PROJECT/docs/specs" "$PROJECT/stub-bin"
  telemetry_setup  # BTS-497
}

teardown() {
  telemetry_teardown  # BTS-497 — first so bats state vars are still pristine
  rm -rf "$PROJECT"
}

# Write a minimal spec at docs/spec.md with feature-id and Summary.
_write_spec_active() {
  local feature_id="${1:-bts-x-test-feature}"
  local summary_first_line="${2:-Test feature first line.}"
  cat > "$PROJECT/docs/spec.md" <<EOF
# Feature: Test

> Feature: $feature_id
> Work: linear:BTS-X
> Created: 1700000000
> Status: In Progress

## Summary

$summary_first_line

## Acceptance Criteria

- [ ] AC-1
EOF
}

# Write a minimal spec at docs/specs/<feature-id>.md (post-cleanup archive).
_write_spec_archive() {
  local feature_id="${1:-bts-x-test-feature}"
  local summary_first_line="${2:-Archive feature first line.}"
  cat > "$PROJECT/docs/specs/$feature_id.md" <<EOF
# Feature: Test

> Feature: $feature_id
> Work: linear:BTS-X
> Created: 1700000000
> Status: Complete

## Summary

$summary_first_line

## Acceptance Criteria

- [ ] AC-1
EOF
}

# Stub gh: records argv to stub-log; on `pr view` returns whatever GH_VIEW_TITLE is.
_with_gh_stub() {
  local title="$1"
  cat > "$PROJECT/stub-bin/gh" <<EOF
#!/usr/bin/env bash
echo "----CALL----" >> "$PROJECT/stub-log"
echo "ARGV: \$*" >> "$PROJECT/stub-log"
case "\$1 \$2" in
  "pr view")
    echo "$title"
    ;;
  "pr edit")
    echo "stub: pr edit accepted"
    ;;
  *)
    echo "stub gh: unhandled subcommand \$1 \$2" >&2
    exit 1
    ;;
esac
exit 0
EOF
  chmod +x "$PROJECT/stub-bin/gh"
}

# =========================================================================
# AC-1: no-op happy path
# =========================================================================

@test "AC-1: title matches expected → updated:false, no gh pr edit call" {
  set -e
  _write_spec_active "bts-x-test" "Test feature first line."
  # BTS-181: derive-pr-title strips at first period — expected has no trailing dot.
  _with_gh_stub "feat(bts-x-test): Test feature first line"

  PATH="$PROJECT/stub-bin:$PATH" run bash "$SCRIPT" assert-pr-title 100 --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.updated == false'
  echo "$output" | jq -e '.expected == "feat(bts-x-test): Test feature first line"'

  # gh pr view called, gh pr edit NOT called.
  grep -q "pr view" "$PROJECT/stub-log"
  ! grep -q "pr edit" "$PROJECT/stub-log"
}

# =========================================================================
# AC-2: force-update on placeholder-shaped title
# =========================================================================

@test "AC-2: feat(auth-system) placeholder → updated:true with gh pr edit call" {
  set -e
  _write_spec_active "bts-x-test" "Test feature first line."
  _with_gh_stub "feat(auth-system): Auth feature."

  PATH="$PROJECT/stub-bin:$PATH" run bash "$SCRIPT" assert-pr-title 100 --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.updated == true'
  echo "$output" | jq -e '.actual == "feat(auth-system): Auth feature."'
  # BTS-181: derive-pr-title strips at first period.
  echo "$output" | jq -e '.expected == "feat(bts-x-test): Test feature first line"'

  grep -q "pr edit" "$PROJECT/stub-log"
  grep -q "feat(bts-x-test): Test feature first line" "$PROJECT/stub-log"
}

@test "AC-2: feat(default) placeholder → force-update" {
  set -e
  _write_spec_active "bts-y" "Y feature summary."
  _with_gh_stub "feat(default): Some default."

  PATH="$PROJECT/stub-bin:$PATH" run bash "$SCRIPT" assert-pr-title 200 --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.updated == true'
  grep -q "pr edit" "$PROJECT/stub-log"
}

@test "AC-2: title without feat(<feature-id>): prefix → force-update" {
  set -e
  _write_spec_active "bts-z" "Z summary."
  _with_gh_stub "Random title without feat prefix"

  PATH="$PROJECT/stub-bin:$PATH" run bash "$SCRIPT" assert-pr-title 300 --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.updated == true'
  grep -q "pr edit" "$PROJECT/stub-log"
}

# =========================================================================
# AC-3: prefix matches but suffix differs → no-op (trust user edits)
# =========================================================================

@test "AC-3: feat(<feature-id>) prefix with user-edited suffix → no-op" {
  set -e
  _write_spec_active "bts-x-test" "Original first line."
  _with_gh_stub "feat(bts-x-test): User edited the descriptive part"

  PATH="$PROJECT/stub-bin:$PATH" run bash "$SCRIPT" assert-pr-title 100 --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.updated == false'

  ! grep -q "pr edit" "$PROJECT/stub-log"
}

# =========================================================================
# AC-4: post-cleanup spec recovery via branch name
# =========================================================================

@test "AC-4: docs/spec.md absent → recovers feature-id from branch and reads archive" {
  set -e
  _write_spec_archive "bts-w-archived-feature" "Archive feature first line."

  # Set up a real-ish git env so `git branch --show-current` reports the
  # claude/feat/<id> branch. mktemp PROJECT is already a dir.
  ( cd "$PROJECT" && git init -q && git checkout -q -b claude/feat/bts-w-archived-feature )

  _with_gh_stub "feat(auth-system): wrong title"
  PATH="$PROJECT/stub-bin:$PATH" run bash "$SCRIPT" assert-pr-title 100 --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.updated == true'
  # BTS-181: derive-pr-title strips at first period.
  echo "$output" | jq -e '.expected == "feat(bts-w-archived-feature): Archive feature first line"'
}

# =========================================================================
# AC-5: missing spec → non-zero exit with clear error
# =========================================================================

@test "AC-5: no spec.md, no archive → non-zero exit, no gh pr edit" {
  set -e
  ( cd "$PROJECT" && git init -q && git checkout -q -b claude/feat/bts-missing )

  _with_gh_stub "feat(auth-system): something"
  PATH="$PROJECT/stub-bin:$PATH" run bash "$SCRIPT" assert-pr-title 100 --project-dir "$PROJECT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no spec found"* ]] || [[ "$stderr" == *"no spec found"* ]]
  # gh pr edit was not called (no stub-log written if gh wasn't even invoked).
  if [[ -f "$PROJECT/stub-log" ]]; then
    ! grep -q "pr edit" "$PROJECT/stub-log"
  fi
}

# =========================================================================
# AC-6: gh CLI unavailable → non-zero exit
# =========================================================================

@test "AC-6: gh not on PATH → non-zero exit with clear error" {
  set -e
  _write_spec_active "bts-x" "summary"
  # Keep coreutils available (so bash itself + grep + sed work) but exclude
  # any directory containing gh. Build a sanitized PATH from system dirs
  # minus typical gh install locations.
  local sanitized_path
  sanitized_path=$(echo "$PATH" | tr ':' '\n' | grep -v -E '/(homebrew|local)/(bin|opt/gh)' | tr '\n' ':')
  # Verify the sanitized PATH doesn't contain gh. If it still does (system
  # has gh in /usr/bin or similar), skip — this test can't run cleanly.
  if PATH="$sanitized_path" command -v gh >/dev/null 2>&1; then
    skip "system has gh in non-homebrew PATH dirs — AC-6 test environment can't isolate"
  fi
  run env PATH="$sanitized_path" bash "$SCRIPT" assert-pr-title 100 --project-dir "$PROJECT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"gh CLI not available"* ]] || [[ "$stderr" == *"gh CLI not available"* ]]
}
