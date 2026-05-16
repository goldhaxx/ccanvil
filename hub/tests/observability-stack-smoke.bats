#!/usr/bin/env bats
# BTS-497 Step 8 — AC-8: docker-compose stack scaffold smoke tests.
#
# Validates the static structure of .ccanvil/observability/docker-compose.yml
# without requiring the stack to be running. Live up/down verification
# (curl http://127.0.0.1:13133, :3001/api/health, :3200/ready) happens at
# commit time per the spec's live-API risk gate (BTS-171), not in bats.
#
# Bats skips gracefully when `docker` is not on PATH — keeps the suite
# CI-friendly on runners without docker, while still gating the developer
# pre-commit flow.

COMPOSE="$BATS_TEST_DIRNAME/../../.ccanvil/observability/docker-compose.yml"

setup() {
  command -v docker >/dev/null 2>&1 || skip "docker cli not on PATH"
  [ -f "$COMPOSE" ] || skip "docker-compose.yml not yet created"
}

# =========================================================================
# Compose syntax validation
# =========================================================================

@test "AC-8: docker compose config exits 0 (yaml syntax + references resolve)" {
  run docker compose -f "$COMPOSE" config --quiet
  [ "$status" -eq 0 ]
}

# =========================================================================
# Services declared (AC-8: Collector + Tempo + Grafana standalone)
# =========================================================================

@test "AC-8: stack declares otel-collector, tempo, grafana services" {
  local cfg
  cfg=$(docker compose -f "$COMPOSE" config --format=json)
  echo "$cfg" | jq -e '.services["otel-collector"]' >/dev/null
  echo "$cfg" | jq -e '.services["tempo"]' >/dev/null
  echo "$cfg" | jq -e '.services["grafana"]' >/dev/null
}

# =========================================================================
# Port mappings — AC-8 explicit port allocation
# =========================================================================

@test "AC-8: grafana publishes host port 3001 (operator's :3000 unaffected)" {
  local cfg
  cfg=$(docker compose -f "$COMPOSE" config --format=json)
  echo "$cfg" | jq -e '
    .services.grafana.ports[]?
    | select((.published // (. | tostring | split(":")[0])) == "3001" or .published == 3001)
  ' >/dev/null
}

@test "AC-8: tempo publishes host port 3200 (tempo HTTP API)" {
  local cfg
  cfg=$(docker compose -f "$COMPOSE" config --format=json)
  echo "$cfg" | jq -e '
    .services.tempo.ports[]?
    | select((.published // (. | tostring | split(":")[0])) == "3200" or .published == 3200)
  ' >/dev/null
}

@test "AC-8: otel-collector publishes OTLP gRPC 4317 + HTTP 4318" {
  local cfg
  cfg=$(docker compose -f "$COMPOSE" config --format=json)
  for port in 4317 4318; do
    echo "$cfg" | jq -e --arg p "$port" '
      .services["otel-collector"].ports[]?
      | select((.published // (. | tostring | split(":")[0])) == $p or .published == ($p | tonumber))
    ' >/dev/null || { echo "MISSING port $port on otel-collector" >&2; return 1; }
  done
}

@test "AC-8: otel-collector publishes healthcheckv2 port 13133" {
  local cfg
  cfg=$(docker compose -f "$COMPOSE" config --format=json)
  echo "$cfg" | jq -e '
    .services["otel-collector"].ports[]?
    | select((.published // (. | tostring | split(":")[0])) == "13133" or .published == 13133)
  ' >/dev/null
}

# =========================================================================
# Bind-mount for fileexporter output
# (AC-10: raw-traces.jsonl lives on the host so otel-flatten.sh reads it
#  without docker exec)
# =========================================================================

@test "AC-10: otel-collector bind-mounts raw-traces.jsonl into the container" {
  local cfg
  cfg=$(docker compose -f "$COMPOSE" config --format=json)
  # The bind mount source path should resolve to .../observability/raw-traces.jsonl
  # The target inside the container should be at /var/lib/otel/raw-traces.jsonl
  echo "$cfg" | jq -e '
    .services["otel-collector"].volumes[]?
    | select(.type == "bind" and (.source | test("raw-traces\\.jsonl$")) and .target == "/var/lib/otel/raw-traces.jsonl")
  ' >/dev/null
}

# =========================================================================
# Pinned image versions (must match what was prefetched)
# =========================================================================

@test "AC-8: otel-collector image pinned to otel/opentelemetry-collector-contrib:0.117.0" {
  local cfg
  cfg=$(docker compose -f "$COMPOSE" config --format=json)
  local image
  image=$(echo "$cfg" | jq -r '.services["otel-collector"].image')
  [ "$image" = "otel/opentelemetry-collector-contrib:0.117.0" ]
}

@test "AC-8: tempo image pinned to grafana/tempo:2.7.0" {
  local cfg
  cfg=$(docker compose -f "$COMPOSE" config --format=json)
  local image
  image=$(echo "$cfg" | jq -r '.services.tempo.image')
  [ "$image" = "grafana/tempo:2.7.0" ]
}

@test "AC-8: grafana image pinned to grafana/grafana:11.4.0" {
  local cfg
  cfg=$(docker compose -f "$COMPOSE" config --format=json)
  local image
  image=$(echo "$cfg" | jq -r '.services.grafana.image')
  [ "$image" = "grafana/grafana:11.4.0" ]
}
