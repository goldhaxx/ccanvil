#!/usr/bin/env bats
# Tests for the idea-upgrade feature.
# Covers:
#   - docs-check.sh title-from-body (AC-9..AC-12)
#   - docs-check.sh idea-upgrade (AC-1..AC-8)
#   - archive-only semantic on Linear-configured nodes (AC-13..AC-16)
#   - documentation + dispatch (AC-17..AC-18)

DOCS_CHECK="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/docs-check.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  PROJECT=$(mktemp -d)
  mkdir -p "$PROJECT/.ccanvil"
}

teardown() {
  rm -rf "$PROJECT"
}

# =========================================================================
# AC-9, AC-12: title-from-body short-text fast path + empty body edge case
# =========================================================================

@test "AC-9: title-from-body returns single-line body <=80 chars verbatim" {
  run bash "$DOCS_CHECK" title-from-body "hello world"
  [ "$status" -eq 0 ]
  [ "$output" = "hello world" ]
}

@test "AC-9: title-from-body returns exactly-80-char single-line body verbatim" {
  body=$(printf 'x%.0s' {1..80})
  run bash "$DOCS_CHECK" title-from-body "$body"
  [ "$status" -eq 0 ]
  [ "$output" = "$body" ]
  [ "${#output}" -eq 80 ]
}

@test "AC-12: title-from-body returns empty string for empty body, exit 0" {
  run bash "$DOCS_CHECK" title-from-body ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "AC-9: title-from-body accepts body on stdin" {
  run bash -c "echo 'piped body' | '$DOCS_CHECK' title-from-body"
  [ "$status" -eq 0 ]
  [ "$output" = "piped body" ]
}
