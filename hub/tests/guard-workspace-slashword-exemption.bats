#!/usr/bin/env bats
# BTS-173: guard-workspace.sh exempts single-segment slash-prefixed
# alphabetic-leading tokens (slash-command names like /idea,
# /permissions-review) from the path scan so heredoc bodies, prose
# strings, and commit-message narratives don't trigger the fence.
#
# Sister test of BTS-169 (pure-slash exemption). Each test pipes a
# synthetic PreToolUse JSON envelope to the hook script and asserts
# on exit code (and stderr message for blocked cases).

bats_require_minimum_version 1.5.0

# BTS-497 telemetry hooks.
source "$BATS_TEST_DIRNAME/_helpers/telemetry.bash"
setup_file()    { telemetry_setup_file; }
teardown_file() { telemetry_teardown_file; }
setup()         { telemetry_setup; }
teardown()      { telemetry_teardown; }

HOOK="$BATS_TEST_DIRNAME/../../.claude/hooks/guard-workspace.sh"

_run_hook() {
  local cmd="$1"
  local input
  input=$(jq -n --arg cmd "$cmd" '{tool_name: "Bash", tool_input: {command: $cmd}}')
  run bash -c "printf '%s' \"\$0\" | '$HOOK'" "$input"
}

# =========================================================================
# AC-1: slash-command names in heredoc bodies pass the fence
# =========================================================================

@test "AC-1: cat heredoc with /idea token in body → exit 0" {
  # Triggers verb `cat`. After quote-stripping the heredoc text becomes
  # whitespace-separated tokens; /idea reaches the path scan as a token.
  _run_hook "cat <<EOF
slash-command /idea is captured here
EOF"
  [ "$status" -eq 0 ]
}

@test "AC-1: bash -c with /permissions-review in echo arg → exit 0" {
  _run_hook 'bash -c "echo /permissions-review walk-through"'
  [ "$status" -eq 0 ]
}

@test "AC-1: cat with multiple slash-command names mixed in prose → exit 0" {
  _run_hook 'cat <<<"the /idea and /spec and /stasis flows are fine"'
  [ "$status" -eq 0 ]
}

# =========================================================================
# AC-2: real outside-workspace path still blocks (regression-guard)
# =========================================================================

@test "AC-2: rm /etc/passwd still blocks" {
  _run_hook "rm /etc/passwd"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "BLOCKED"
  echo "$output" | grep -q "/etc/passwd"
}

# =========================================================================
# AC-3: nested-segment absolute still blocks
# =========================================================================

@test "AC-3: mv /var/log/foo /tmp/bar still blocks on the var/log prefix" {
  _run_hook "mv /var/log/foo /tmp/bar"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "BLOCKED"
  echo "$output" | grep -q "/var/log/foo"
}

# =========================================================================
# AC-4: BTS-169 regression — pure-slash tokens still pass
# =========================================================================

@test "AC-4: BTS-169 regression — // operator still exempt" {
  _run_hook "cat data.json | jq '.foo // null'"
  [ "$status" -eq 0 ]
}

@test "AC-4: BTS-169 regression — /// pure-slash still exempt" {
  _run_hook 'bash -c "echo ///"'
  [ "$status" -eq 0 ]
}

# =========================================================================
# AC-5: edge — non-alphabetic-leading single-segment NOT exempted
# =========================================================================

@test "AC-5: rm /123foo (numeric-leading single segment) still blocks" {
  # /123foo would be a real (if unusual) absolute path. Numeric-leading
  # tokens fall through the exemption and hit the path scan.
  _run_hook "rm /123foo"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "BLOCKED"
}

@test "AC-5: rm /_hidden (underscore-leading) still blocks" {
  _run_hook "rm /_hidden"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "BLOCKED"
}

# =========================================================================
# AC-6: edge — long single-segment NOT exempted (length cap)
# =========================================================================

@test "AC-6: rm /abcdefghijklmnopqrstuvwxyzabcd123 (33 chars) still blocks" {
  # 33 chars after the slash exceeds the 30-char cap; falls through to
  # path scan.
  _run_hook "rm /abcdefghijklmnopqrstuvwxyzabcd123"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "BLOCKED"
}

# =========================================================================
# AC-7: drift-guard — exemption rule annotated with BTS-173
# =========================================================================

@test "AC-7: guard-workspace.sh exemption rule references BTS-173 inline" {
  grep -q "BTS-173" "$HOOK"
}

# =========================================================================
# Allowlist semantics — unknown slash-command-shaped tokens still block
# =========================================================================

@test "allowlist: unknown /not-a-real-command name still blocks via path scan" {
  # /not-a-real-command is alpha-leading single-segment but NOT in the
  # .claude/commands/ or .claude/skills/ allowlist. Hits the path scan.
  _run_hook "rm /not-a-real-command"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "BLOCKED"
}

@test "allowlist: real system path /etc still blocks (collision with potential cmd)" {
  # /etc happens to be a single-segment alphabetic token; without the
  # allowlist filter, the broad regex would have exempted it. Confirm
  # the allowlist correctly leaves /etc on the blocked side.
  _run_hook 'find /etc -name foo'
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "/etc"
}
