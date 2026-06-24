#!/usr/bin/env bats

# BTS-497 telemetry hooks.
source "$BATS_TEST_DIRNAME/_helpers/telemetry.bash"
setup_file()    { telemetry_setup_file; }
teardown_file() { telemetry_teardown_file; }
setup()         { telemetry_setup; }
teardown()      { telemetry_teardown; }

# Tests for ci-status-check.sh — the PostToolUse CI-state advisory.
# These exercise the self-gating (network-free) paths only: the gh-polling
# path is integration-tested live, not in bats. Every assertion here must hold
# with NO network and regardless of whether `gh` is installed.

HOOK="$BATS_TEST_DIRNAME/../../.claude/hooks/ci-status-check.sh"

# A directory guaranteed to have NO .github/workflows, so the CI-config gate
# trips and the hook is a silent no-op even if gh happens to be authed.
no_ci_dir() { mkdir -p "$BATS_TEST_TMPDIR/no-ci" && printf '%s' "$BATS_TEST_TMPDIR/no-ci"; }

@test "ci-status-check: silent no-op on a non-push git command" {
  input='{"tool_name":"Bash","tool_input":{"command":"git status"}}'
  run bash -c "echo '$input' | '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "ci-status-check: silent no-op when 'push' is not a git subcommand" {
  input='{"tool_name":"Bash","tool_input":{"command":"npm run push-assets"}}'
  run bash -c "echo '$input' | '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "ci-status-check: silent no-op on 'git pushups' (push must be a whole token)" {
  input='{"tool_name":"Bash","tool_input":{"command":"git pushups"}}'
  run bash -c "echo '$input' | '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "ci-status-check: silent no-op for a git push in a repo with no CI config" {
  dir="$(no_ci_dir)"
  input='{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}'
  run bash -c "cd '$dir' && echo '$input' | '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "ci-status-check: CI_STATUS_CHECK_DISABLE short-circuits before any work" {
  input='{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}'
  run bash -c "CI_STATUS_CHECK_DISABLE=1 echo '$input' | CI_STATUS_CHECK_DISABLE=1 '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "ci-status-check: empty / malformed stdin is a silent no-op" {
  run bash -c "echo '' | '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run bash -c "echo 'not json' | '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "ci-status-check: passes shellcheck-style bash syntax" {
  run bash -n "$HOOK"
  [ "$status" -eq 0 ]
}
