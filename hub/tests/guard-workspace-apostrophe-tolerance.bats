#!/usr/bin/env bats
# BTS-234: guard-workspace.sh tolerates apostrophe-s possessives on slash-
# command-name tokens. Extends BTS-210's trailing-punct tolerance so prose
# like `/recall's wrap`, `/idea's BTS-X`, and `/recall's.` pass through
# when the leading portion matches a known slash-command.
#
# Sister test of BTS-173 (allowlist) and BTS-210 (trailing-punct).

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
# AC-1: apostrophe-s tolerated when leading matches allowlist
# =========================================================================

@test "AC-1: /recall's passes (apostrophe-s, the origin trigger)" {
  _run_hook $'cat <<<"during /recall\'s wrap"'
  [ "$status" -eq 0 ]
}

@test "AC-1: /idea's passes" {
  _run_hook $'cat <<<"after /idea\'s capture flow"'
  [ "$status" -eq 0 ]
}

@test "AC-1: /spec's passes" {
  _run_hook $'cat <<<"during /spec\'s ACs"'
  [ "$status" -eq 0 ]
}

# =========================================================================
# AC-2: apostrophe-s + trailing punct (combines BTS-210 and BTS-234)
# =========================================================================

@test "AC-2: /recall's. passes (apostrophe-s + period)" {
  _run_hook $'cat <<<"wrap /recall\'s."'
  [ "$status" -eq 0 ]
}

@test "AC-2: /stasis's, passes (apostrophe-s + comma)" {
  _run_hook $'cat <<<"during /stasis\'s, then more"'
  [ "$status" -eq 0 ]
}

@test "AC-2: /pr's; passes (apostrophe-s + semicolon)" {
  _run_hook $'cat <<<"after /pr\'s; check"'
  [ "$status" -eq 0 ]
}

# =========================================================================
# AC-3: regression — BTS-210 trailing-punct still works (no apostrophe)
# =========================================================================

@test "AC-3: /stasis). still passes (BTS-210 baseline)" {
  _run_hook 'cat <<<"surfaced during /stasis)."'
  [ "$status" -eq 0 ]
}

@test "AC-3: /idea, still passes (BTS-210 baseline)" {
  _run_hook 'cat <<<"during /idea, capture flow"'
  [ "$status" -eq 0 ]
}

# =========================================================================
# AC-4: single-quoted absolute path STILL blocks (security parity)
# =========================================================================

@test "AC-4: rm '/etc/passwd' still blocks — quoted-path security parity" {
  _run_hook $'rm \'/etc/passwd\''
  [ "$status" -eq 2 ]
}

@test "AC-4: cat '/etc/shadow' still blocks" {
  _run_hook $'cat \'/etc/shadow\''
  [ "$status" -eq 2 ]
}

# =========================================================================
# AC-5: apostrophe-s on UNKNOWN slash-command still blocks
# =========================================================================

@test "AC-5: /unknown's still blocks (not in allowlist)" {
  _run_hook $'cat <<<"poke at /unknown\'s thing"'
  [ "$status" -eq 2 ]
}

@test "AC-5: /xyzzyfoo's still blocks (made-up name)" {
  _run_hook $'cat <<<"poke at /xyzzyfoo\'s"'
  [ "$status" -eq 2 ]
}

# =========================================================================
# AC-6: bare unknown path still blocks (regression baseline)
# =========================================================================

@test "AC-6: /etc still blocks (no apostrophe, no allowlist match)" {
  _run_hook 'cat <<<"poke at /etc"'
  [ "$status" -eq 2 ]
}

# =========================================================================
# Drift-guard: BTS-234 reference inline in guard-workspace.sh
# =========================================================================

@test "drift: BTS-234 referenced inline in guard-workspace.sh" {
  grep -q "BTS-234" "$HOOK"
}
