#!/usr/bin/env bats
# BTS-497 Step 11 — bats telemetry helper foundation.
#
# Helper file: hub/tests/_helpers/telemetry.bash
# Public functions tested here:
#   telemetry_setup_file    (AC-2 healthcheck, AC-5 otel-cli check, span server)
#   telemetry_teardown_file (cleanup)
#
# Attribute resolution + per-test emission tests live in Step 12.
# Live span round-trip lives in Step 12.

HELPER="$BATS_TEST_DIRNAME/_helpers/telemetry.bash"

setup() {
  [ -f "$HELPER" ] || skip "telemetry helper not yet created"
  # Isolate BATS_FILE_TMPDIR — bats normally sets it but a sub-bats invocation
  # gets its own; here we use a fresh dir per test.
  export BATS_FILE_TMPDIR="$BATS_TEST_TMPDIR/file"
  mkdir -p "$BATS_FILE_TMPDIR"
}

# =========================================================================
# Disabled-mode no-op (substrate self-tests via --no-telemetry)
# =========================================================================

@test "AC-7: CCANVIL_TELEMETRY_DISABLED=1 → setup_file is a no-op (returns 0)" {
  # The disabled flag must short-circuit before any curl/otel-cli probe.
  # PATH state is irrelevant to the assertion (helper must return 0
  # regardless of whether tools are present), so don't shadow it.
  CCANVIL_TELEMETRY_DISABLED=1 run bash -c "source '$HELPER' && telemetry_setup_file"
  [ "$status" -eq 0 ]
}

# =========================================================================
# AC-5 — otel-cli missing → exit non-zero + actionable message
# =========================================================================

@test "AC-5: missing otel-cli → setup_file exits non-zero + names install command" {
  # PATH inside the bash subshell is shadowed so `command -v otel-cli`
  # fails. /bin/bash via absolute path so the subshell is reachable
  # regardless of outer PATH state.
  run /bin/bash -c "PATH=/nonexistent; source '$HELPER' && telemetry_setup_file"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qE 'otel-cli'
  echo "$output" | grep -qE 'brew install.*otel-cli'
}

# =========================================================================
# AC-2 — unreachable Collector → setup_file exits non-zero
# =========================================================================

@test "AC-2: unreachable Collector → setup_file exits non-zero + names start command" {
  # Point at a port that's certainly closed.
  CCANVIL_TELEMETRY_URL="http://127.0.0.1:1" run bash -c "source '$HELPER' && telemetry_setup_file"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qE 'Collector|healthcheck'
  echo "$output" | grep -qE 'docker compose'
}

# =========================================================================
# Public-surface assertions: functions defined, attribute env vars exported
# =========================================================================

@test "AC-7: helper defines telemetry_setup_file + telemetry_teardown_file + telemetry_setup + telemetry_teardown" {
  source "$HELPER"
  declare -F telemetry_setup_file >/dev/null
  declare -F telemetry_teardown_file >/dev/null
  declare -F telemetry_setup >/dev/null
  declare -F telemetry_teardown >/dev/null
}

# =========================================================================
# Idempotent disable: teardown is also a no-op under DISABLED
# =========================================================================

@test "AC-7: CCANVIL_TELEMETRY_DISABLED=1 → teardown_file is a no-op (returns 0)" {
  CCANVIL_TELEMETRY_DISABLED=1 run bash -c "source '$HELPER' && telemetry_teardown_file"
  [ "$status" -eq 0 ]
}
