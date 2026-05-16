# Test Observability — Schema Contract

Runner-neutral schema for ccanvil's test-observability stack. Versioned `v1.0.0`. Two schemas live here: the OTel **span schema** (emitted by every test runner via OTel-compatible exporters) and the **flat JSONL record schema** (derived by `otel-flatten.sh` from the OTel Collector's `fileexporter` output for agent-readable per-test queries).

The schema is single-source for both ccanvil's bats runner (Stage 1) and downstream-node distillation to pytest / vitest / go-test / cargo (Stage 2, per BTS-499). Any future runner emits the same shape; `runner.kind` discriminates.

Spec references: BTS-497 AC-9 (span schema), AC-10 (flat record schema), AC-12 (idempotency keys + schema_version requirement).

## Span Schema

Version: v1.0.0

Every test span emitted via OTel (regardless of runner) carries the following attributes. Required attributes must be present on every span; optional attributes are present only when the field is meaningful for the outcome.

| Attribute | Type | Required | Description |
|---|---|---|---|
| `test.name` | string | required | The test's human-readable name (bats `@test "<name>"`; pytest `test_<name>`; vitest `it("<name>")`). |
| `test.file` | string | required | Path to the test source file, repo-relative (e.g. `hub/tests/idea-add.bats`). |
| `test.outcome` | enum | required | One of `{pass, fail, skip}`. Exactly one of these three string literals; no other values permitted. |
| `worker.id` | integer ∈ ℕ | required | Parallel-worker index. `0` when running single-file (not parallelized); `1..N` when parallelized. Source: `${PARALLEL_JOBSLOT:-0}` for bats; runner-equivalent env var for pytest/vitest/go-test. |
| `runner.kind` | enum (string) | required | Test-framework identifier. Enumerated values: `bats`, `pytest`, `vitest`, `jest`, `go`, `cargo`. Extensible — new runners append to this list in subsequent schema versions. |
| `run.id` | string | required | Unique per suite-run identifier. Format: `<epoch_seconds>-<pid>` where epoch is the suite-start unix timestamp and pid is the orchestrator (`bats-report.sh` / equivalent) process id. |
| `git.sha` | string | required | Full git SHA of HEAD at suite-start. Resolves via `git rev-parse HEAD`; cached once per suite. |
| `test.duration_ms` | number | optional | Wall-clock duration of the test in milliseconds. Optional because some runners cannot emit wall time until span close; consumers must tolerate absence. |
| `test.error_excerpt` | string | optional | First ~200 chars of the failure message when `test.outcome=fail`. Present iff `test.outcome=fail`; absent on pass/skip. |

`run.id` is the primary join key across spans within a single suite run. `(run.id, span.id)` is the unique identity for a single test span — `span.id` is provided by the OTel SDK / `otel-cli` (16-hex-char unique-per-span identifier per the OTel spec) and is NOT a user attribute.

## Flat JSONL Record Schema

Version: v1.0.0

Derived from the span schema by `.ccanvil/observability/otel-flatten.sh`, which reads the OTel Collector `fileexporter` output (OTLP `ExportTraceServiceRequest` envelopes, one per batch) at `.ccanvil/observability/raw-traces.jsonl` and emits one flat JSON record per span to `.ccanvil/state/test-runs.jsonl`.

Fields are snake_cased (not dotted) for `jq` ergonomics. Reading agents query the sidecar directly:

```
jq -c 'select(.test_outcome=="fail")' .ccanvil/state/test-runs.jsonl
```

No API, container, or running Collector is required at read time.

| Field | Type | Required | Mirrors span attribute | Notes |
|---|---|---|---|---|
| `run_id` | string | required | `run.id` | Same format `<epoch>-<pid>`. |
| `span_id` | string | required | OTel span `spanId` | 16-hex-char unique-per-span identifier per the OTel spec. Provided by the OTel SDK / `otel-cli`, NOT a user attribute. Required in the flat schema because `(run_id, span_id)` is the idempotency pair `otel-flatten.sh` uses for set-difference dedup; the pair must be reconstructible from the sidecar alone. |
| `test_name` | string | required | `test.name` | |
| `test_file` | string | required | `test.file` | |
| `test_outcome` | enum | required | `test.outcome` | One of `{pass, fail, skip}`. |
| `worker_id` | integer | required | `worker.id` | |
| `runner_kind` | enum (string) | required | `runner.kind` | |
| `git_sha` | string | required | `git.sha` | |
| `started_at_unix_nano` | integer | required | OTel span `startTimeUnixNano` | Nanosecond-resolution start; used to order spans within a run. |
| `duration_ms` | number | optional | `test.duration_ms` | Bats helper always populates this in practice, but the flatten step drops null/absent fields via `with_entries(select(.value != null))` — so a span emitted without `test.duration_ms` produces a flat record without `duration_ms`, no error. Consumers should defensive-check `if .duration_ms then ...`. Future runners under BTS-499 that emit ungauged spans (e.g., custom test frameworks) will simply omit the field rather than fail the pipeline. |
| `error_excerpt` | string | optional | `test.error_excerpt` | Present iff `test_outcome=fail`; absent on pass/skip. |
| `schema_version` | string | required | n/a | Required on every record. Value: `"v1.0.0"`. Consumers fail-fast on version mismatch — older readers must reject newer records they don't understand, rather than silently drop fields. |

### Idempotency key

The flatten step (AC-12) uses `(run_id, span_id)` as the unique identity. On each invocation, `otel-flatten.sh` builds a hash-set of existing `(run_id, span_id)` pairs from the sidecar via O(1) jq object lookup, then filters new candidates against that set — only previously-unseen pairs are appended. Byte-equality of JSON lines is NOT the idempotency key (the OTel Collector may reorder spans across batches, producing semantically-equivalent but byte-different lines for the same span).

## Schema evolution

Backward-incompatible changes bump the major version (`v1.0.0` → `v2.0.0`). Backward-compatible field additions bump minor (`v1.0.0` → `v1.1.0`). Consumers MUST reject records whose `schema_version` major component exceeds the consumer's supported major.

The bats helper (`hub/tests/_helpers/telemetry.bash`) and the flatten step (`.ccanvil/observability/otel-flatten.sh`) are the only producers of `schema_version` on the ccanvil side. Downstream runners adopting this schema (per BTS-499) emit their own producers but conform to the same versioning rules.
