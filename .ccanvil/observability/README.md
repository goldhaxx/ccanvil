# Test Observability — BTS-497

Local-only OpenTelemetry stack for ccanvil's bats test suite. Spans flow from each `@test` through an OTel Collector into Grafana Tempo; a deterministic flattener also produces a `jq`-readable per-test JSONL sidecar at `.ccanvil/state/test-runs.jsonl` for offline / agent-driven queries.

Schema is runner-neutral (per `SCHEMA.md`) so the same pipeline extends to pytest / vitest / go-test under BTS-499.

## Quickstart

```bash
# One-time: install otel-cli (the bats helper invokes it per test).
brew install equinix-labs/otel-cli/otel-cli

# Start the stack (Collector + Tempo + Grafana, all on 127.0.0.1).
docker compose -f .ccanvil/observability/docker-compose.yml up -d

# Run the bats suite — every test now emits a span.
bash .ccanvil/scripts/bats-report.sh --parallel

# Open the dashboard:
open http://127.0.0.1:3001            # Grafana (admin/admin)
#   → Dashboards → ccanvil → Test Runs Overview
```

## Start / Stop / Status

```bash
# Bring up the stack.
docker compose -f .ccanvil/observability/docker-compose.yml up -d

# Stop the stack but keep volumes (traces/dashboards survive).
docker compose -f .ccanvil/observability/docker-compose.yml stop

# Tear down + delete volumes (clean slate).
docker compose -f .ccanvil/observability/docker-compose.yml down -v

# Check container status.
docker compose -f .ccanvil/observability/docker-compose.yml ps
```

## Healthcheck

| Service | Endpoint | Expected |
|---|---|---|
| Collector | `http://127.0.0.1:13133` | `{"status":"Server available", ...}` |
| Tempo | `http://127.0.0.1:3200/ready` | `ready` (200) |
| Grafana | `http://127.0.0.1:3001/api/health` | `{database:ok, ...}` |

One-liner:

```bash
for url in http://127.0.0.1:13133 http://127.0.0.1:3200/ready http://127.0.0.1:3001/api/health; do
  echo "$url: $(curl -fsS -o /dev/null -w '%{http_code}' "$url")"
done
```

Tempo's `/ready` returns 503 for ~25s after first start (ingester warm-up) — re-check after a wait.

## Port allocation

| Port | Service | Purpose |
|---|---|---|
| 3001 | Grafana | Dashboards (host); container default :3000 remapped to avoid colliding with any other Grafana the operator is running. |
| 3200 | Tempo | HTTP API + Grafana datasource. |
| 4317 | Collector | OTLP gRPC receiver. |
| 4318 | Collector | OTLP HTTP receiver (the bats helper uses this). |
| 13133 | Collector | `health_check` extension. |

All ports bind to `127.0.0.1` only — the stack is local-only by design. No external access.

## Opt out (substrate self-tests, offline)

The bats suite runs without the OTel stack when `--no-telemetry` is passed:

```bash
bash .ccanvil/scripts/bats-report.sh --parallel --no-telemetry
```

Effects:
- Disables the bats helper's per-test span emission (no curl, no otel-cli).
- Skips the post-run flatten step (a missing `raw-traces.jsonl` does not propagate exit 78).
- `docs-check.sh test-suite-run` skips its AC-2 healthcheck precondition.

Useful when iterating on substrate that itself touches the helper, when running offline, or when the stack is intentionally down.

## Troubleshooting

**Suite-run aborts with `ERROR: OTel Collector healthcheck unreachable`.** The dispatcher's AC-2 precondition fires before bats forks. Start the stack (`docker compose up -d`) or pass `--no-telemetry` to bypass.

**`otel-cli not on PATH` during suite-run.** The bats helper's setup_file requires `otel-cli`. Install: `brew install equinix-labs/otel-cli/otel-cli`.

**Exit code 78 from bats-report.sh.** Per AC-12d, exit 78 (sysexits.h `EX_CONFIG`) means the post-run `otel-flatten.sh` failed — almost always either (a) the Collector is down so no spans were emitted, or (b) `raw-traces.jsonl` is missing/malformed. Check the stderr line above the exit; usually points at the recovery action.

**Some tests don't appear in Tempo / test-runs.jsonl.** Common causes: commas in test names (the helper sanitizes them to semicolons; if you see commas back, the sanitization broke); test never wired the helper into its setup_file (only the 10-file Phase D sample is instrumented as of BTS-497 — full rollout in BTS-504).

**Tempo says `/ready` returns 503.** Normal for ~25s after fresh start. Wait. If persistent, check `docker compose logs tempo` for ingester errors.

**Grafana dashboard panels show "no data".** Confirm spans are landing via `curl -fsS http://127.0.0.1:3200/api/search?tags=service.name%3Dccanvil-test | jq`. If spans are in Tempo but panels are empty, the panels' TraceQL queries may need refinement (full metrics-aggregation lands with BTS-500's metrics-generator).

## Files in this directory

| File | Purpose |
|---|---|
| `docker-compose.yml` | Three-service stack: Collector + Tempo + Grafana. |
| `otel-collector-config.yaml` | OTLP receivers + Tempo exporter + fileexporter + healthcheck. |
| `tempo.yaml` | Tempo single-binary config (local backend, 7d retention). |
| `grafana/provisioning/datasources/tempo.yaml` | Auto-registered Tempo datasource. |
| `grafana/provisioning/dashboards/test-runs.yaml` | Dashboard provider config. |
| `grafana/provisioning/dashboards/test-runs-overview.json` | Test Runs Overview dashboard. |
| `otel-flatten.sh` | Deterministic OTLP → flat JSONL normalizer (AC-10, AC-12). |
| `SCHEMA.md` | Span schema + flat record schema contract (v1.0.0). |
| `.gitignore` | Excludes the live `raw-traces.jsonl` from git. |
| `raw-traces.jsonl` | Local-only Collector output (gitignored). |

## Reference

- Spec: `docs/specs/bts-497-test-otel-stack.md` (Linear: BTS-497).
- Research: `docs/research/test-performance-research.md` (4-stream open-market scan that converged on this architecture).
- Follow-up tickets: BTS-498 (drift-guard outlier), BTS-499 (Stage-2 distillation), BTS-500 (metrics layer), BTS-501 (logs layer), BTS-502 (regression alerts), BTS-504 (remaining bats wiring).
