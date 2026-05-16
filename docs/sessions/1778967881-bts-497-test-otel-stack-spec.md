# Feature: Test Observability — OTel Stack (Foundation)

> Feature: bts-497-test-otel-stack
> Work: linear:BTS-497
> Created: 1778911599
> Subject: Test Observability — OTel Stack (Foundation)
> Status: Draft

## Summary

Stand up the foundation of the OpenTelemetry-based test observability stack for ccanvil's bats suite. Each `@test` emits an OTel span via `otel-cli`; spans flow through a local OTel Collector into Grafana Tempo; the operator views per-test traces and swimlanes in Grafana. The bats `setup_file` hook fails the suite if the Collector's healthcheck endpoint is unreachable — observability is non-optional. The schema and pipeline are runner-neutral so Stage 2 distillation (BTS-499) can extend to pytest/vitest/go-test without re-derivation. Follow-on specs add metrics (Mimir), logs (Loki), and regression alert rules.

## Job To Be Done

**When** running the bats test suite (any invocation: iteration, `/pr`, or CI),
**I want to** automatically emit per-test timing + worker-id telemetry into Grafana,
**So that** I can see which tests are slow, when parallel scheduling stalled, and how the suite behaves over time — and never run blind because telemetry is silently broken.

## Acceptance Criteria

- [ ] **AC-1:** Given a running local OTel Collector (docker-compose) + Tempo, when `bats-report.sh --parallel` runs, each `@test` produces exactly one OTel span in Tempo with attributes `test.name`, `test.file`, `test.outcome`, `worker.id`, `runner.kind="bats"`, `git.sha`, `run.id`.
- [ ] **AC-2:** Given the OTel Collector is unreachable at suite start, when any `.bats` file runs, `setup_file` exits non-zero with a clear error message and zero tests run.
- [ ] **AC-3:** Given a successful suite run with N parallel jobs (N = the `bats-report.sh` resolved perf-core count; 12 on the operator's M4 Max), when the operator opens the Grafana Tempo trace-detail view for that run, they see one span per test grouped into N swimlanes by `worker.id`. AC is machine-agnostic; specific N is determined at runtime via `sysctl -n hw.perflevel0.physicalcpu` per BTS-277.
- [ ] **AC-4:** Given multiple successful runs, when the operator opens the provisioned "Test Runs Overview" dashboard, they see per-run wall time, test count, and outcome summary as time-series + a "Slowest tests across last 7d" panel.
- [ ] **AC-5:** Error path: when `otel-cli` is not installed on the host, `setup_file` emits an actionable error message naming the install command and exits non-zero.
- [ ] **AC-6:** Edge path: when bats runs single-file (not via `--jobs N`), `worker.id` is set to `0` and the span still emits; no error, no warning, no missing field.
- [ ] **AC-7:** The bats helper that emits spans lives in `hub/tests/_helpers/telemetry.bash`, is sourced once per `.bats` file via shared `setup_file`, and adds no per-test wall-time regression > 50 ms vs. the pre-instrumentation baseline (measured via `bats-runs.jsonl` pre/post deltas).
- [ ] **AC-8:** The OTel Collector + Tempo + **standalone Grafana** + their configs all live in `.ccanvil/observability/` as a self-contained docker-compose; `docker compose up -d` from that directory brings the full stack online with no external dependencies. **Port allocation:** Grafana 3001 (operator's existing Grafana on 3000 unaffected), Tempo 3200, OTel Collector OTLP gRPC 4317 / OTLP HTTP 4318, Collector healthcheckv2 13133. No port-conflict with existing services.
- [ ] **AC-9:** Schema documented as a runner-neutral contract in `.ccanvil/observability/SCHEMA.md` — every span attribute typed, semver'd, marked required vs optional. Future runners (pytest, vitest) emit the same shape.
- [ ] **AC-10:** Per-test JSONL sidecar at `.ccanvil/state/test-runs.jsonl` is written at end-of-suite by the deterministic normalizer `.ccanvil/observability/otel-flatten.sh`, which reads the OTel Collector `fileexporter` output at `.ccanvil/observability/raw-traces.jsonl` (OTLP `ExportTraceServiceRequest` envelopes, one per batch) and flattens it into one JSON record per test span. Each record has the shape `{run_id, test_name, test_file, test_outcome, worker_id, runner_kind, git_sha, started_at_unix_nano, duration_ms, error_excerpt?, schema_version}` and is agent-readable via `jq -c 'select(.test_outcome=="fail")' .ccanvil/state/test-runs.jsonl` with no API, container, or running Collector required at read time.
- [ ] **AC-11:** Human-readable stdout from `bats-report.sh --parallel` includes a config line of the form `parallel: jobs=N cpus=M wall=Ts` immediately above the existing `PASS / FAIL / TOTAL` summary. JSON mode is unchanged. The operator sees parallelization config without grepping the JSON envelope or `bats-runs.jsonl`.
- [ ] **AC-12:** The flatten step ships in-the-box and runs fail-closed. Given a `<run_id>` argument, `.ccanvil/observability/otel-flatten.sh <run_id>` (a) filters `raw-traces.jsonl` to spans matching `<run_id>` and emits one canonical JSON record per span to `.ccanvil/state/test-runs.jsonl` (append mode); (b) is **key-idempotent on** `(run_id, span_id)` — each record's `(run_id, span_id)` pair is the unique identity (span_id is the OTel-spec 16-hex-char unique-per-span identifier), so re-running on the same `<run_id>` appends only records whose `(run_id, span_id)` is not already present in the sidecar and exits 0; byte-equality of JSON lines is NOT the idempotency key (OTel Collector batching may reorder spans across runs, producing semantically-equivalent but byte-different lines for the same span); (c) exits with sentinel code **78 (**`EX_CONFIG` **per sysexits.h)** and an actionable stderr message when `raw-traces.jsonl` is missing, malformed, or empty for the given `<run_id>` — observability-layer failures are distinct from test failures; (d) is invoked by `bats-report.sh` after every `--parallel` run; **exit-code precedence rule:** when flatten fails, `bats-report.sh` exits 78 **regardless of** `bats_rc` (flatten failure is the "running blind" signal AC-2 guards against and must always surface); when flatten succeeds, `bats-report.sh` exits with `bats_rc` (test failures propagate normally so CI behavior is preserved). The `bats_rc` value remains visible in human stdout (PASS/FAIL summary) and in the `bats-runs.jsonl` JSON envelope regardless of which code is propagated, so JSON consumers can still distinguish test-failure runs even when 78 is the exit code.

## Affected Files

| File | Change |
| -- | -- |
| `hub/tests/_helpers/telemetry.bash` | New — bats helper with `telemetry_setup_file` + `telemetry_teardown` |
| `hub/tests/_helpers/manifest-validate-cache.bash` | Modified — add telemetry sourcing pattern |
| All `hub/tests/*.bats` | Modified — source telemetry helper in `setup_file` (159 files; one-line edit each) |
| `.ccanvil/scripts/bats-report.sh` | Modified — `--no-telemetry` escape hatch; invoke `otel-flatten.sh` after every `--parallel` run; fail suite-run on flatten failure |
| `.ccanvil/scripts/docs-check.sh` | Modified — `cmd_test_suite_run` requires healthcheck precondition |
| `.ccanvil/observability/docker-compose.yml` | New — Collector + Tempo + Grafana |
| `.ccanvil/observability/otel-collector-config.yaml` | New — OTLP receiver + Tempo exporter + `fileexporter` to `raw-traces.jsonl` |
| `.ccanvil/observability/grafana/provisioning/datasources/tempo.yaml` | New |
| `.ccanvil/observability/grafana/provisioning/dashboards/test-runs.yaml` | New |
| `.ccanvil/observability/SCHEMA.md` | New — span schema contract + flat JSONL record schema (both versioned `v1.0.0`) |
| `.ccanvil/observability/README.md` | New — operator onboarding + start/stop runbook |
| `.ccanvil/observability/otel-flatten.sh` | New — deterministic normalizer (OTLP envelopes → flat per-span JSONL) |
| `.ccanvil/observability/.gitignore` | New — exclude `raw-traces.jsonl` (local-only artifact, may grow large) |
| `.ccanvil/manifest-allowlist.txt` | Modified — register telemetry helper + `otel-flatten.sh` |
| `hub/tests/telemetry-helper.bats` | New — covers AC-1, AC-2, AC-5, AC-6, AC-7 |
| `hub/tests/observability-stack-smoke.bats` | New — covers AC-3, AC-4, AC-8 (docker-compose smoke) |
| `hub/tests/otel-flatten.bats` | New — covers AC-10 (schema shape on real `raw-traces.jsonl` fixture) + AC-12 (idempotency, fail-closed, suite-run propagation) |

## Dependencies

* **Requires:** `otel-cli` v0.4+ installed on operator's machine (`brew install equinix-labs/otel-cli/otel-cli`); Docker Desktop or compatible engine for the observability stack.
* **Blocked by:** None.
* **Blocks:** BTS-499 (Stage-2 distillation — needs the schema to be load-bearing first); follow-on specs for Mimir metrics + Loki logs + regression alert rules.

## Out of Scope

* Metrics layer (Mimir / Prometheus) — separate follow-on spec.
* Logs layer (Loki / Promtail) — separate follow-on spec.
* Regression detection alert rules — separate follow-on spec.
* Stage-2 distillation to non-bats test providers — BTS-499.
* Drift-guard outlier optimization — BTS-498.
* CI integration of the observability stack — local-only first ship; CI is a follow-on once local validates.
* Backfilling historical `bats-runs.jsonl` data into Tempo — past runs are unrecoverable.

## Implementation Notes

* **Pattern:** `otel-cli span background` mode runs a unix-socket span server per `setup_file`, so per-test `otel-cli exec` calls are microseconds rather than fresh OTLP connects. Reference: `docs/research/test-performance-research.md` §10.4 and Howard John's bash-OTel blog.
* **Worker-ID source:** `${PARALLEL_JOBSLOT:-0}` — set by GNU parallel when bats shells out via `--jobs N`. Caveat: may not be set in single-file parallel mode; AC-6 covers the fallback.
* **Parallelization is machine-dependent.** Current configured value (12) is `hw.perflevel0.physicalcpu` on M4 Max per BTS-277 benchmark (2026-05-02). On Intel hosts / Linux / CI runners the value falls back to `max(2, hw.logicalcpu/2)`. AC-3 must remain machine-agnostic so the spec holds on downstream nodes (BTS-499) running on different hardware.
* **AC-11 surfaces config in human stdout** — currently jobs/cpus/wall_ms only land in `--json` mode and `bats-runs.jsonl`. This closes a long-standing observability gap operator-flagged 2026-05-16.
* **Grafana deployment is standalone** — operator decision 2026-05-16. ccanvil's Grafana runs on port 3001 alongside (not merged with) the operator's existing Grafana on port 3000. Rationale: (a) downstream-node distribution via BTS-499 needs a turnkey stack, not a "wire-into-existing-Grafana" recipe; (b) dashboard provenance lives entirely in the ccanvil repo; (c) lifecycle decoupled from any other project's Grafana. Trade-off accepted: \~150 MB additional resident RAM for second Grafana instance.
* **Fail-closed pattern:** `curl -fsS --max-time 2 "${CCANVIL_TELEMETRY_URL}/health"` against OTel Collector's `healthcheckv2extension` endpoint. Standard across all runners — reference: `docs/research/test-performance-research.md` §10.5.
* **Span schema (AC-9):** `test.name`, `test.file`, `test.outcome ∈ {pass, fail, skip}`, `worker.id ∈ ℕ`, `runner.kind ∈ {bats, pytest, vitest, go, ...}`, `run.id` (epoch-pid), `git.sha`, optional `test.duration_ms`, optional `test.error_excerpt`. Versioned at `v1.0.0`.
* **Flat JSONL record schema (AC-10 / AC-12):** mirrors the span schema, snake_cased for `jq` ergonomics — `{run_id, test_name, test_file, test_outcome, worker_id, runner_kind, git_sha, started_at_unix_nano, duration_ms, error_excerpt?, schema_version: "v1.0.0"}`. The optional `error_excerpt` is present iff `test_outcome=="fail"`. `schema_version` is required on every record so consumers can fail-fast on version mismatch.
* **Why end-of-suite normalization (AC-10):** matches the existing `bats-runs.jsonl` cadence (suite-level summary, one record per RUN). Per-test write contention is avoided — the bats helper has a single emission point (`otel-cli`); the flat JSONL derives from the Collector's batched output deterministically. Reading `.ccanvil/state/test-runs.jsonl` from agents requires no running Collector, no docker, no network — it's a local file.
* **Idempotency (AC-12):** the idempotency key is `(run_id, span_id)`, NOT byte-identity. `span_id` is the OTel-spec 16-hex unique-per-span identifier carried in every OTLP envelope; it is stable across Collector re-invocations even when batch ordering changes. `otel-flatten.sh` builds the new batch (canonical-emit via `jq -c -S` for sorted-keys output — purely so diffs in the JSONL stay reviewable), then computes the set difference: `new_records − {(run_id, span_id) ∈ existing}`. Only records whose `(run_id, span_id)` is not already present in `.ccanvil/state/test-runs.jsonl` are appended. Re-invoking on the same `<run_id>` after a successful prior flatten appends zero records and exits 0. The append is atomic via `>>` with O_APPEND semantics — concurrent flatten invocations for distinct `<run_id>`s do not corrupt the file.
* **Collector** `fileexporter` **config:** writes to `/var/lib/otel/raw-traces.jsonl` inside the container, bind-mounted to `.ccanvil/observability/raw-traces.jsonl` on the host. Rotation: `fileexporter.rotation.max_megabytes: 100` (Collector-native rotation, operational concern not contract). The file is gitignored — it's local-only runtime state, not source.
* **Live-API risk (BTS-171):** the docker-compose stack is a live external system — AC-3/AC-4/AC-8 require running the stack end-to-end before commit, not just stubbing the Collector. The "stub passes, live fails" failure mode applies.
* **Performance budget (AC-7):** the BTS-281 fixture-cache pattern handles validate cost; OTel emission adds \~1-3 ms per test via the unix-socket span server. Budget: 50 ms p95 marginal cost across the suite vs. pre-instrumentation baseline (current p50 = 83 ms, p95 = 1075 ms — telemetry must not move these visibly).
* **Reference architecture:** `docs/research/test-performance-research.md` §10.2.
* **Memory anchors:** `[[project_bts_497_path_2_decision]]`, `[[reference_test_observability_stack]]`, `[[feedback_test_framework_two_paradigm]]`.

## Layman summary

This ship is the foundation of the test-observability system the operator approved as Path 2. Every test that runs gets its timing automatically recorded and shipped to a local Grafana dashboard — the operator can see how the parallel scheduling is playing out, which tests are slow, and how the suite changes over time. If the recording system isn't running, the tests refuse to run at all — observability is non-optional, by design. This is a one-machine setup: nothing leaves the operator's laptop unless they choose otherwise. The schema is intentionally runner-neutral so the next ticket (BTS-499) can extend the same pipeline to projects using pytest, vitest, or other test tools without re-deriving the design.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
