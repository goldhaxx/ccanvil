# BTS-497 — bats telemetry helper (runner-neutral OTel emission).
#
# Sourced once per .bats file via shared setup_file() / teardown_file() and
# per @test via setup() / teardown(). Emits one OTel span per @test to the
# local Collector at $CCANVIL_OTLP_ENDPOINT (default http://127.0.0.1:4318),
# carrying the runner-neutral attribute set documented in
# .ccanvil/observability/SCHEMA.md (v1.0.0).
#
# Public functions:
#   telemetry_setup_file    — healthcheck + otel-cli probe + start span server
#   telemetry_teardown_file — stop span server (flushes pending spans)
#   telemetry_setup         — capture per-test start nanoseconds
#   telemetry_teardown      — emit one span with the AC-1 attribute set
#
# Env overrides:
#   CCANVIL_TELEMETRY_URL       healthcheck endpoint (default http://127.0.0.1:13133)
#   CCANVIL_OTLP_ENDPOINT       OTLP HTTP endpoint   (default http://127.0.0.1:4318)
#   CCANVIL_TELEMETRY_DISABLED  any value disables the helper entirely
#                               (used by --no-telemetry escape hatch in
#                                bats-report.sh — Plan Step 14)
#
# Step 11 ships setup_file + teardown_file + setup + teardown skeletons.
# Step 12 adds the full attribute resolution + span emission inside teardown.

telemetry_setup_file() {
  # AC-7 / Step 14 escape hatch: disabled mode is a hard no-op so substrate
  # self-tests run without the stack.
  if [[ -n "${CCANVIL_TELEMETRY_DISABLED:-}" ]]; then
    return 0
  fi

  # AC-5: otel-cli must be installed.
  if ! command -v otel-cli >/dev/null 2>&1; then
    echo "ERROR: otel-cli not on PATH — required by BTS-497 test observability" >&2
    echo "Install: brew install equinix-labs/otel-cli/otel-cli" >&2
    return 1
  fi

  # AC-2: Collector healthcheck must respond 200.
  local url="${CCANVIL_TELEMETRY_URL:-http://127.0.0.1:13133}"
  if ! curl -fsS --max-time 2 "$url" >/dev/null 2>&1; then
    echo "ERROR: OTel Collector healthcheck unreachable at $url" >&2
    echo "Start: docker compose -f .ccanvil/observability/docker-compose.yml up -d" >&2
    return 1
  fi

  # Start the unix-socket span server in the background. Per-test emission
  # uses the socket (microseconds) rather than fresh OTLP connects (~ms).
  local sockdir="$BATS_FILE_TMPDIR/otel"
  mkdir -p "$sockdir"
  local endpoint="${CCANVIL_OTLP_ENDPOINT:-http://127.0.0.1:4318}"
  otel-cli span background \
    --sockdir "$sockdir" \
    --endpoint "$endpoint" \
    --protocol http/protobuf \
    --service ccanvil-test \
    >/dev/null 2>&1 &
  local pid=$!
  echo "$pid" > "$BATS_FILE_TMPDIR/telemetry-pid"

  # Wait briefly for the socket to materialize (server-ready signal).
  local i=0
  while [[ ! -S "$sockdir/socket" ]] && (( i < 50 )); do
    sleep 0.05
    i=$((i + 1))
  done
  if [[ ! -S "$sockdir/socket" ]]; then
    echo "ERROR: otel-cli span background failed to create socket at $sockdir/socket" >&2
    kill "$pid" 2>/dev/null || true
    return 1
  fi

  # Cache file-scope invariants once. Per-test setup/teardown read these
  # rather than re-resolving (git rev-parse is a fork, $PARALLEL_JOBSLOT
  # never changes within a file).
  export BTS_TELEMETRY_SOCKDIR="$sockdir"
  export BTS_TELEMETRY_RUN_ID="${BTS_RUN_ID:-$(date +%s)-$$}"
  export BTS_TELEMETRY_GIT_SHA="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
  export BTS_TELEMETRY_WORKER_ID="${PARALLEL_JOBSLOT:-0}"
}

telemetry_teardown_file() {
  if [[ -n "${CCANVIL_TELEMETRY_DISABLED:-}" ]]; then
    return 0
  fi
  if [[ -f "${BATS_FILE_TMPDIR:-}/telemetry-pid" ]]; then
    local pid
    pid=$(cat "$BATS_FILE_TMPDIR/telemetry-pid")
    kill "$pid" 2>/dev/null || true
    # Wait briefly for clean shutdown — span server flushes pending spans on
    # SIGTERM. Suppress wait errors when the pid is already gone.
    wait "$pid" 2>/dev/null || true
  fi
}

telemetry_setup() {
  if [[ -n "${CCANVIL_TELEMETRY_DISABLED:-}" ]]; then
    return 0
  fi
  # Step 12 expands this: record test start in nanoseconds for the
  # test.duration_ms attribute computed in teardown.
  export BTS_TELEMETRY_TEST_START_NS="$(date +%s%N 2>/dev/null || echo 0)"
}

telemetry_teardown() {
  if [[ -n "${CCANVIL_TELEMETRY_DISABLED:-}" ]]; then
    return 0
  fi
  # Step 12 implements the full span emission. Step 11 keeps the function
  # defined-but-no-op so per-test wiring lands without breaking the suite.
  return 0
}
