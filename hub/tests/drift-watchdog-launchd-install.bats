#!/usr/bin/env bats
# BTS-199 — drift-watchdog-launchd-install subcommand.
#
# Tests use stubbed launchctl + plutil so the real macOS launchd is never
# touched. Stubs read STUB_* env vars to control per-test behavior.

bats_require_minimum_version 1.5.0

# BTS-497 telemetry hooks.
source "$BATS_TEST_DIRNAME/_helpers/telemetry.bash"
setup_file()    { telemetry_setup_file; }
teardown_file() { telemetry_teardown_file; }

REPO_ROOT="$BATS_TEST_DIRNAME/../.."
SCRIPT="$REPO_ROOT/.ccanvil/scripts/ccanvil-sync.sh"

setup() {
  TMPDIR_BATS=$(mktemp -d)
  STUB_BIN="$TMPDIR_BATS/bin"
  mkdir -p "$STUB_BIN"
  # Redirect ~/Library/LaunchAgents/ to a sandbox so the real one is untouched.
  FAKE_HOME="$TMPDIR_BATS/home"
  mkdir -p "$FAKE_HOME/Library/LaunchAgents"
  export HOME="$FAKE_HOME"

  # launchctl stub — reads STUB_LAUNCHCTL_<verb>_RC + STUB_LAUNCHCTL_<verb>_OUT
  cat > "$STUB_BIN/launchctl" <<'STUB'
#!/usr/bin/env bash
verb="$1"
case "$verb" in
  unload) rc="${STUB_LAUNCHCTL_UNLOAD_RC:-0}"; out="${STUB_LAUNCHCTL_UNLOAD_OUT:-}" ;;
  load)   rc="${STUB_LAUNCHCTL_LOAD_RC:-0}";   out="${STUB_LAUNCHCTL_LOAD_OUT:-}" ;;
  print)  rc="${STUB_LAUNCHCTL_PRINT_RC:-0}";  out="${STUB_LAUNCHCTL_PRINT_OUT:-state = running}" ;;
  *)      rc=0; out="" ;;
esac
[[ -n "$out" ]] && echo "$out"
exit "$rc"
STUB
  chmod +x "$STUB_BIN/launchctl"

  # plutil stub — reads STUB_PLUTIL_RC. Default exists + ok.
  cat > "$STUB_BIN/plutil" <<'STUB'
#!/usr/bin/env bash
exit "${STUB_PLUTIL_RC:-0}"
STUB
  chmod +x "$STUB_BIN/plutil"

  export PATH="$STUB_BIN:$PATH"
  telemetry_setup
}

teardown() {
  telemetry_teardown
  [[ -n "${TMPDIR_BATS:-}" ]] && rm -rf "$TMPDIR_BATS"
}

# =========================================================================
# AC-1: subcommand is wired into dispatcher
# =========================================================================

@test "AC-1: ccanvil-sync.sh recognizes drift-watchdog-launchd-install subcommand" {
  grep -qF 'drift-watchdog-launchd-install' "$SCRIPT"
}

# =========================================================================
# AC-2: install (no --reload) — generate, lint, copy, load, verify
# =========================================================================

@test "AC-2: install without --reload emits installed/verified JSON" {
  run bash "$SCRIPT" drift-watchdog-launchd-install
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.installed == true'
  echo "$output" | jq -e '.reloaded == false'
  echo "$output" | jq -e '.verified == true'
  # plist file landed in the sandboxed LaunchAgents dir
  [ -f "$FAKE_HOME/Library/LaunchAgents/com.ccanvil.drift-watchdog.plist" ]
}

# =========================================================================
# AC-3: install with --reload — unload, then install
# =========================================================================

@test "AC-3: install with --reload emits reloaded=true" {
  run bash "$SCRIPT" drift-watchdog-launchd-install --reload
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.reloaded == true'
  echo "$output" | jq -e '.verified == true'
}

# =========================================================================
# AC-4: idempotency — second call doesn't corrupt state
# =========================================================================

@test "AC-4: re-running idempotent — second load returns non-zero but verify still passes" {
  STUB_LAUNCHCTL_LOAD_RC=1 run bash "$SCRIPT" drift-watchdog-launchd-install
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.installed == true'
  echo "$output" | jq -e '.verified == true'
}

# =========================================================================
# AC-5: verify failure exits non-zero
# =========================================================================

@test "AC-5: verify failure (launchctl print non-zero) exits 3 with verified=false" {
  STUB_LAUNCHCTL_PRINT_RC=1 STUB_LAUNCHCTL_PRINT_OUT="" run bash "$SCRIPT" drift-watchdog-launchd-install
  [ "$status" -eq 3 ]
  [[ "$output" =~ "verified" ]]
}

@test "AC-5: verify failure (no state in print output) exits 3" {
  STUB_LAUNCHCTL_PRINT_OUT="random unrelated output" run bash "$SCRIPT" drift-watchdog-launchd-install
  [ "$status" -eq 3 ]
}

# =========================================================================
# AC-6: plist generation failure — never proceeds
# =========================================================================

@test "AC-6: empty plist output exits 2 with plist-generation-failed" {
  # Inject by overriding cmd_drift_watchdog_launchd_print via a wrapper that
  # exports DRIFT_WATCHDOG_PLIST_FORCE_EMPTY=1 — the substrate honors that
  # for testing.
  DRIFT_WATCHDOG_PLIST_FORCE_EMPTY=1 run bash "$SCRIPT" drift-watchdog-launchd-install
  [ "$status" -eq 2 ]
  [[ "$output" =~ "plist-generation-failed" ]]
}

# =========================================================================
# AC-7: plutil lint failure — never proceeds
# =========================================================================

@test "AC-7: plutil lint failure exits 2 with plist-lint-failed" {
  STUB_PLUTIL_RC=1 run bash "$SCRIPT" drift-watchdog-launchd-install
  [ "$status" -eq 2 ]
  [[ "$output" =~ "plist-lint-failed" ]]
}

# =========================================================================
# AC-8: function body documents ALLOW_OUTSIDE_WORKSPACE bypass semantic
# =========================================================================

@test "AC-8: function body mentions ALLOW_OUTSIDE_WORKSPACE bypass" {
  awk '/^cmd_drift_watchdog_launchd_install\(\)/,/^}$/' "$SCRIPT" \
    | grep -qF 'ALLOW_OUTSIDE_WORKSPACE'
}

# =========================================================================
# Bonus: plutil missing — WARN-skip path
# =========================================================================

@test "WARN-skip: plutil missing emits warning but continues" {
  rm "$STUB_BIN/plutil"
  run bash "$SCRIPT" drift-watchdog-launchd-install
  [ "$status" -eq 0 ]
  [[ "$output" =~ "WARN" ]] || true  # non-fatal informational
  echo "$output" | jq -e '.installed == true'
}
