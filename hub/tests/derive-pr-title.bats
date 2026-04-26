#!/usr/bin/env bats
# BTS-181 — derive-pr-title substrate primitive.
#
# Factor PR-title derivation duplicated between cmd_activate and
# cmd_assert_pr_title into one cmd_derive_pr_title that emits
# `feat(<feature-id>): <truncated-summary>` to stdout.
#
# Truncation: first period strips suffix; remaining suffix capped at 80 chars.

bats_require_minimum_version 1.5.0

SCRIPT="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/docs-check.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  PROJECT=$(mktemp -d)
  mkdir -p "$PROJECT/docs"
}

teardown() {
  rm -rf "$PROJECT"
}

# Write a spec at $1 with feature_id $2 and Summary first line $3.
_write_spec() {
  local path="$1"
  local feature_id="$2"
  local summary="$3"
  cat > "$path" <<EOF
# Feature: Test

> Feature: $feature_id
> Work: linear:BTS-X
> Created: 1700000000
> Status: Draft

## Summary

$summary

## Acceptance Criteria

- [ ] AC-1
EOF
}

# =========================================================================
# AC-1: happy path — emits feat(<id>): <first-line>
# =========================================================================

@test "AC-1: emits feat(<feature-id>): <first-line> from Summary" {
  set -e
  _write_spec "$PROJECT/docs/spec.md" "bts-x-test" "Short feature line."
  run bash "$SCRIPT" derive-pr-title "$PROJECT/docs/spec.md"
  [ "$status" -eq 0 ]
  [ "$output" = "feat(bts-x-test): Short feature line" ]
}

# =========================================================================
# AC-2: ≤80 chars, no period → verbatim
# =========================================================================

@test "AC-2: ≤80 chars without period emits verbatim" {
  set -e
  _write_spec "$PROJECT/docs/spec.md" "bts-x" "Short bare line"
  run bash "$SCRIPT" derive-pr-title "$PROJECT/docs/spec.md"
  [ "$status" -eq 0 ]
  [ "$output" = "feat(bts-x): Short bare line" ]
}

# =========================================================================
# AC-3: period-strip
# =========================================================================

@test "AC-3: first period strips remaining text" {
  set -e
  _write_spec "$PROJECT/docs/spec.md" "bts-x" "Add foo. Bar baz."
  run bash "$SCRIPT" derive-pr-title "$PROJECT/docs/spec.md"
  [ "$status" -eq 0 ]
  [ "$output" = "feat(bts-x): Add foo" ]
}

# =========================================================================
# AC-4: 80-char truncation when no period in first 80
# =========================================================================

@test "AC-4: long line without period truncates suffix at 80 chars" {
  set -e
  # 120 chars, no periods
  local line="aaaaaaaaaa bbbbbbbbbb cccccccccc dddddddddd eeeeeeeeee ffffffffff gggggggggg hhhhhhhhhh iiiiiiiiii jjjjjjjjjj kkkkkkkkkk"
  _write_spec "$PROJECT/docs/spec.md" "bts-x" "$line"
  run bash "$SCRIPT" derive-pr-title "$PROJECT/docs/spec.md"
  [ "$status" -eq 0 ]
  # Suffix after `feat(bts-x): ` is exactly 80 chars; expected suffix is
  # the first 80 chars of $line, with no trailing whitespace.
  local expected_suffix="${line:0:80}"
  expected_suffix="${expected_suffix%"${expected_suffix##*[![:space:]]}"}"
  [ "$output" = "feat(bts-x): $expected_suffix" ]
  # Also: no trailing whitespace after parameter expansion.
  [[ ! "$output" =~ [[:space:]]$ ]]
}

# =========================================================================
# AC-5: empty Summary → activate-feature fallback
# =========================================================================

@test "AC-5: empty Summary section emits activate-feature fallback" {
  set -e
  cat > "$PROJECT/docs/spec.md" <<EOF
# Feature: Test

> Feature: bts-x-empty
> Work: linear:BTS-X
> Created: 1700000000
> Status: Draft

## Summary

## Acceptance Criteria

- [ ] AC-1
EOF
  run bash "$SCRIPT" derive-pr-title "$PROJECT/docs/spec.md"
  [ "$status" -eq 0 ]
  [ "$output" = "feat(bts-x-empty): activate feature" ]
}

# =========================================================================
# AC-6: missing/bad input → non-zero exit, no stdout
# =========================================================================

@test "AC-6: missing argument → non-zero exit, error on stderr, no stdout" {
  run --separate-stderr bash "$SCRIPT" derive-pr-title
  [ "$status" -ne 0 ]
  [ -z "$output" ]
  [[ "$stderr" == *"missing"* || "$stderr" == *"derive-pr-title"* ]]
}

@test "AC-6: non-existent file → non-zero exit" {
  run bash "$SCRIPT" derive-pr-title "$PROJECT/docs/does-not-exist.md"
  [ "$status" -ne 0 ]
}

# =========================================================================
# AC-9: drift-guard — both call sites delegate to the primitive
# =========================================================================

@test "AC-9: cmd_activate no longer inlines the Summary sed extraction" {
  set -e
  # Find the line range of cmd_activate() and grep within it.
  local start end
  start=$(grep -n '^cmd_activate()' "$SCRIPT" | head -1 | cut -d: -f1)
  [ -n "$start" ]
  # End = next top-level `^cmd_` definition.
  end=$(awk -v s="$start" 'NR > s && /^cmd_[a-z_]+\(\)/ { print NR; exit }' "$SCRIPT")
  [ -n "$end" ]
  ! sed -n "${start},${end}p" "$SCRIPT" | grep -q "sed -n '/^## Summary"
}

@test "AC-9: cmd_assert_pr_title no longer inlines the Summary sed extraction" {
  set -e
  local start end
  start=$(grep -n '^cmd_assert_pr_title()' "$SCRIPT" | head -1 | cut -d: -f1)
  [ -n "$start" ]
  end=$(awk -v s="$start" 'NR > s && /^cmd_[a-z_]+\(\)/ { print NR; exit }' "$SCRIPT")
  [ -n "$end" ]
  ! sed -n "${start},${end}p" "$SCRIPT" | grep -q "sed -n '/^## Summary"
}
