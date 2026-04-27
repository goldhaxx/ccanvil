#!/usr/bin/env bats
# BTS-210: guard-workspace.sh tolerates a trailing run of prose punctuation
# on slash-command-name tokens. Extends the BTS-173 single-segment
# allowlist match so prose like `/stasis).` and `/idea,` pass through
# when the leading portion matches a known slash-command.
#
# Sister test of BTS-173 (slashword exemption). Each test pipes a
# synthetic PreToolUse JSON envelope to the hook script and asserts
# on exit code.

bats_require_minimum_version 1.5.0

HOOK="$BATS_TEST_DIRNAME/../../.claude/hooks/guard-workspace.sh"

_run_hook() {
  local cmd="$1"
  local input
  input=$(jq -n --arg cmd "$cmd" '{tool_name: "Bash", tool_input: {command: $cmd}}')
  run bash -c "printf '%s' \"\$0\" | '$HOOK'" "$input"
}

# =========================================================================
# AC-1: trailing prose punct tolerated when leading matches allowlist
# =========================================================================

@test "AC-1: /stasis). passes (period+paren — origin trigger)" {
  _run_hook 'cat <<<"surfaced during /stasis)."'
  [ "$status" -eq 0 ]
}

@test "AC-1: /idea, passes (comma)" {
  _run_hook 'cat <<<"during /idea, capture flow"'
  [ "$status" -eq 0 ]
}

@test "AC-1: /spec. passes (period)" {
  _run_hook 'cat <<<"after /spec."'
  [ "$status" -eq 0 ]
}

@test "AC-1: /land: passes (colon)" {
  _run_hook 'cat <<<"during /land:"'
  [ "$status" -eq 0 ]
}

@test "AC-1: /pr; passes (semicolon)" {
  _run_hook 'cat <<<"run /pr; then check"'
  [ "$status" -eq 0 ]
}

@test "AC-1: /radar! passes (exclamation)" {
  _run_hook 'cat <<<"check /radar!"'
  [ "$status" -eq 0 ]
}

@test "AC-1: /recall? passes (question mark)" {
  _run_hook 'cat <<<"try /recall?"'
  [ "$status" -eq 0 ]
}

@test "AC-1: /review) passes (closing paren)" {
  _run_hook 'cat <<<"see comments above /review)"'
  [ "$status" -eq 0 ]
}

@test "AC-1: /plan] passes (closing bracket)" {
  # No leading `[` in the prose — that would prefix the token and bypass
  # the slash-shape check entirely (false-positive of the wrong kind).
  _run_hook 'cat <<<"reference /plan] in body"'
  [ "$status" -eq 0 ]
}

@test "AC-1: /stasis).; passes (multi-char punct run)" {
  _run_hook 'cat <<<"end of /stasis).;"'
  [ "$status" -eq 0 ]
}

# =========================================================================
# AC-3: non-allowlist slash tokens still block (path-shape unchanged)
# =========================================================================

@test "AC-3: rm /etc/foo still blocks" {
  _run_hook "rm /etc/foo"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "BLOCKED"
}

@test "AC-3: rm /var/log still blocks" {
  _run_hook "rm /var/log"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "BLOCKED"
}

@test "AC-3: cat /etc). still blocks (etc is not a slash-command)" {
  _run_hook 'cat <<<"see /etc)."'
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "BLOCKED"
}

# =========================================================================
# AC-4: bare slash-command regression (BTS-173 happy path preserved)
# =========================================================================

@test "AC-4: bare /idea still passes (BTS-173 regression)" {
  _run_hook 'cat <<<"the /idea flow"'
  [ "$status" -eq 0 ]
}

@test "AC-4: bare /permissions-review still passes (BTS-173 regression)" {
  _run_hook 'cat <<<"running /permissions-review now"'
  [ "$status" -eq 0 ]
}

# =========================================================================
# AC-5: multi-segment slash + punct still blocks (allowlist scope)
# =========================================================================

@test "AC-5: /idea/sub). still blocks (multi-segment, not a slash-command)" {
  _run_hook 'cat <<<"see /idea/sub)."'
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "BLOCKED"
}

# =========================================================================
# Drift-guard: BTS-210 reference present in guard-workspace.sh
# =========================================================================

@test "drift: BTS-210 punct-tolerance referenced inline in guard-workspace.sh" {
  grep -q "BTS-210" "$HOOK"
}
