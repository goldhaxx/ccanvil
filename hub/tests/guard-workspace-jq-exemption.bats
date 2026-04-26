#!/usr/bin/env bats
# BTS-169: guard-workspace.sh exempts pure-slash tokens (//, ///, etc.)
# from the path scan so jq's `//` alternative-default operator no longer
# triggers a false-positive "outside workspace" block.
#
# Each test pipes a synthetic PreToolUse JSON envelope to the hook script
# and asserts on exit code (and stderr message for blocked cases).

bats_require_minimum_version 1.5.0

HOOK="$BATS_TEST_DIRNAME/../../.claude/hooks/guard-workspace.sh"

# Helper: build the hook input for a given Bash command and run the hook.
_run_hook() {
  local cmd="$1"
  local input
  input=$(jq -n --arg cmd "$cmd" '{tool_name: "Bash", tool_input: {command: $cmd}}')
  run bash -c "printf '%s' \"\$0\" | '$HOOK'" "$input"
}

# =========================================================================
# AC-1: jq `//` operator passes the workspace fence
# =========================================================================

@test "AC-1: cat-piped jq with // alternative-default → exit 0" {
  # Triggering verb is `cat` (gated); jq is downstream in the pipeline.
  # This is the exact shape of the false-positive surfaced during BTS-150.
  _run_hook "cat data.json | jq '.foo // null'"
  [ "$status" -eq 0 ]
}

@test "AC-1 variant: bash -c with // operator → exit 0" {
  _run_hook 'bash -c "jq .foo // null < data.json"'
  [ "$status" -eq 0 ]
}

@test "AC-1 quoted-default: jq '.foo // \"default\"' (quote-stripping doesn't merge //) → exit 0" {
  # After tr -d '"', the command becomes: cat data.json | jq .foo // default
  # // remains a whitespace-separated token — exemption applies.
  _run_hook 'cat data.json | jq ".foo // \"default\""'
  [ "$status" -eq 0 ]
}

# =========================================================================
# AC-2: real outside-workspace paths still block (regression-guard)
# =========================================================================

@test "AC-2: rm /etc/passwd still blocks" {
  _run_hook "rm /etc/passwd"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "BLOCKED"
  echo "$output" | grep -q "/etc/passwd"
}

@test "AC-2: cp /var/log/foo /tmp/bar still blocks (first violation wins)" {
  _run_hook "cp /var/log/foo /tmp/bar"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "BLOCKED"
  echo "$output" | grep -q "/var/log/foo"
}

# =========================================================================
# AC-3: triple/quad slash also exempt (drift-guard against partial fix)
# =========================================================================

@test "AC-3: bash command containing /// token → exit 0" {
  _run_hook 'bash -c "echo ///"'
  [ "$status" -eq 0 ]
}

@test "AC-3: bash command containing //// token → exit 0" {
  _run_hook 'bash -c "echo ////"'
  [ "$status" -eq 0 ]
}

# =========================================================================
# AC-4: //foo/bar (slash-prefixed but with content) still blocks
# =========================================================================

@test "AC-4: rm //foo/bar still blocks (POSIX vendor path not exempted)" {
  _run_hook "rm //foo/bar"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "BLOCKED"
}

# =========================================================================
# AC-5: bare `/` token continues to be skipped (existing behavior)
# =========================================================================

@test "AC-5: bare '/' token in command → exit 0 (existing /?* case skip)" {
  _run_hook 'bash -c "echo /"'
  [ "$status" -eq 0 ]
}

# =========================================================================
# Defense-in-depth: gated verb without a path arg still allowed
# =========================================================================

@test "passthrough: rm with relative path inside workspace → exit 0" {
  _run_hook "rm relative/path"
  [ "$status" -eq 0 ]
}
