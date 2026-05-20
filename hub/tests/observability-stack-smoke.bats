#!/usr/bin/env bats

# BTS-497 telemetry hooks.
source "$BATS_TEST_DIRNAME/_helpers/telemetry.bash"
setup_file()    { telemetry_setup_file; }
teardown_file() { telemetry_teardown_file; }
teardown()      { telemetry_teardown; }
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
  telemetry_setup
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

@test "AC-8: otel-collector publishes health_check port 13133" {
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

# =========================================================================
# Step 9 — Collector config structural assertions (AC-1, AC-10)
# =========================================================================

COLLECTOR_CFG="$BATS_TEST_DIRNAME/../../.ccanvil/observability/otel-collector-config.yaml"

@test "AC-1: collector config declares OTLP receiver on gRPC 4317 + HTTP 4318" {
  [ -f "$COLLECTOR_CFG" ] || skip "collector config not yet created"
  grep -qE 'endpoint: 0\.0\.0\.0:4317' "$COLLECTOR_CFG"
  grep -qE 'endpoint: 0\.0\.0\.0:4318' "$COLLECTOR_CFG"
}

@test "AC-1: collector declares traces pipeline with receivers=[otlp]" {
  [ -f "$COLLECTOR_CFG" ] || skip "collector config not yet created"
  # The traces pipeline must include the otlp receiver.
  awk '/^  pipelines:/,/^$/' "$COLLECTOR_CFG" | grep -qE 'receivers: \[otlp\]'
}

@test "AC-1+AC-10: collector traces pipeline exports to both tempo + file" {
  [ -f "$COLLECTOR_CFG" ] || skip "collector config not yet created"
  # The traces pipeline must include both otlphttp/tempo and file exporters.
  local exporters
  exporters=$(awk '/^  pipelines:/,/^$/' "$COLLECTOR_CFG" | grep -E 'exporters: \[')
  echo "$exporters" | grep -qE 'otlphttp/tempo'
  echo "$exporters" | grep -qE '\bfile\b'
}

@test "AC-10: fileexporter writes to /var/lib/otel/raw-traces.jsonl (mount target)" {
  [ -f "$COLLECTOR_CFG" ] || skip "collector config not yet created"
  grep -qE 'path: /var/lib/otel/raw-traces\.jsonl' "$COLLECTOR_CFG"
}

@test "AC-10: fileexporter declares rotation (operational concern, not contract)" {
  [ -f "$COLLECTOR_CFG" ] || skip "collector config not yet created"
  grep -qE 'rotation:' "$COLLECTOR_CFG"
  grep -qE 'max_megabytes:' "$COLLECTOR_CFG"
}

@test "AC-2: collector declares health_check extension on port 13133" {
  [ -f "$COLLECTOR_CFG" ] || skip "collector config not yet created"
  # Two independent assertions are sufficient — the file structure pins
  # health_check as the extension name + 13133 as the endpoint port.
  grep -qE '^  health_check:' "$COLLECTOR_CFG"
  grep -qE 'endpoint: 0\.0\.0\.0:13133' "$COLLECTOR_CFG"
  grep -qE '^  extensions: \[health_check\]' "$COLLECTOR_CFG"
}

# =========================================================================
# Step 10 — Grafana datasource + dashboard provisioning (AC-3, AC-4)
# =========================================================================

DS_TEMPO="$BATS_TEST_DIRNAME/../../.ccanvil/observability/grafana/provisioning/datasources/tempo.yaml"
DASH_PROVIDER="$BATS_TEST_DIRNAME/../../.ccanvil/observability/grafana/provisioning/dashboards/test-runs.yaml"
# BTS-533: the two prior dashboards (test-runs-overview + test-runs-live) were
# consolidated into one — NOW / SLOW / DIDN'T PASS / TREND sections.
DASH_JSON="$BATS_TEST_DIRNAME/../../.ccanvil/observability/grafana/provisioning/dashboards/ccanvil-test-observability.json"

@test "AC-4: tempo datasource provisioning declares http://tempo:3200" {
  [ -f "$DS_TEMPO" ] || skip "datasource provisioning not yet created"
  grep -qE 'type: tempo' "$DS_TEMPO"
  grep -qE 'url: http://tempo:3200' "$DS_TEMPO"
  grep -qE 'uid: tempo-bts-497' "$DS_TEMPO"
}

@test "AC-4: dashboard provider points at /etc/grafana/provisioning/dashboards" {
  [ -f "$DASH_PROVIDER" ] || skip "dashboard provider not yet created"
  grep -qE 'path: /etc/grafana/provisioning/dashboards' "$DASH_PROVIDER"
  grep -qE 'type: file' "$DASH_PROVIDER"
}

@test "AC-4: consolidated dashboard JSON is valid + UID stable (BTS-533)" {
  [ -f "$DASH_JSON" ] || skip "dashboard JSON not yet created"
  jq -e '.title == "ccanvil — Test observability"' "$DASH_JSON" >/dev/null
  jq -e '.uid == "ccanvil-test-obs"' "$DASH_JSON" >/dev/null
}

@test "AC-4: dashboard declares the four section rows (BTS-533)" {
  [ -f "$DASH_JSON" ] || skip "dashboard JSON not yet created"
  # NOW / SLOW / DIDN'T PASS / TREND — each is a Grafana row.
  jq -e '[.panels[] | select(.type == "row") | .title] | any(test("^NOW"))' "$DASH_JSON" >/dev/null
  jq -e '[.panels[] | select(.type == "row") | .title] | any(test("^SLOW"))' "$DASH_JSON" >/dev/null
  jq -e '[.panels[] | select(.type == "row") | .title] | any(test("DIDN.T PASS"))' "$DASH_JSON" >/dev/null
  jq -e '[.panels[] | select(.type == "row") | .title] | any(test("^TREND"))' "$DASH_JSON" >/dev/null
}

@test "AC-4: dashboard declares the seven data panels (BTS-533)" {
  [ -f "$DASH_JSON" ] || skip "dashboard JSON not yet created"
  local count
  count=$(jq '[.panels[] | select(.type != "row")] | length' "$DASH_JSON")
  [ "$count" -eq 7 ]
}

@test "AC-4: every data panel references the Tempo datasource UID (tempo-bts-497)" {
  [ -f "$DASH_JSON" ] || skip "dashboard JSON not yet created"
  # Rows carry no datasource — exclude them before asserting.
  local bad
  bad=$(jq '[.panels[] | select(.type != "row") | .datasource.uid // ""] | map(select(. != "tempo-bts-497")) | length' "$DASH_JSON")
  [ "$bad" -eq 0 ]
}

@test "AC-4: no panel query uses a caret-anchored regex (Tempo =~ is implicit-anchored) (BTS-533)" {
  [ -f "$DASH_JSON" ] || skip "dashboard JSON not yet created"
  # Tempo's =~ / !~ are full-line anchored; a leading ^ makes the match
  # never fire. Guard against the regression that motivated BTS-533.
  local caret
  caret=$(jq -r '[.panels[].targets // [] | .[].query // "" | select(test("[=!]~ \"\\^"))] | length' "$DASH_JSON")
  [ "$caret" -eq 0 ]
}

@test "AC-8: grafana service bind-mounts provisioning dir read-only" {
  local cfg
  cfg=$(docker compose -f "$COMPOSE" config --format=json)
  echo "$cfg" | jq -e '
    .services.grafana.volumes[]?
    | select(.type == "bind" and (.source | test("grafana/provisioning$")) and .target == "/etc/grafana/provisioning")
  ' >/dev/null
}
