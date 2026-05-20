# Feature: Generic [otel-span.sh](<http://otel-span.sh>) helper library

> Feature: bts-543-otel-span-helper
> Work: linear:BTS-543
> Created: 1779311468
> Subject: Generic [otel-span.sh](<http://otel-span.sh>) helper library
> Status: In Progress

## Summary

OpenTelemetry span emission is currently welded into the bats telemetry helper (`hub/tests/_helpers/telemetry.bash`) — no other script can emit a span. This feature extracts the generic span mechanics into a new standalone, sourceable library, `.ccanvil/observability/otel-span.sh`, and refactors the bats helper and `bats-report.sh` to consume it. It is the foundation child of the Workflow Observability umbrella (BTS-542): every later child emits spans through this helper. The refactor is strictly behavior-preserving — the existing test-observability dashboard must see byte-identical spans.

## Job To Be Done

**When** any deterministic ccanvil script needs to emit an OTel span,
**I want to** source one shared helper that owns span mechanics (IDs, attributes, emission, graceful-skip),
**So that** instrumentation is a one-line addition per script instead of duplicated, bats-coupled code.

## Acceptance Criteria

Each criterion is independently testable. Binary pass/fail.

- [ ] **AC-1:** `.ccanvil/observability/otel-span.sh` exists as a sourceable library (no CLI dispatch). Sourcing it defines the public functions `otel_span_init`, `otel_span_cache_invariants`, `otel_span_new_trace_id`, `otel_span_new_span_id`, `otel_span_sanitize`, `otel_span_emit`, `otel_span_run`.
- [ ] **AC-2:** `otel_span_new_trace_id` emits exactly 32 lowercase hex characters; `otel_span_new_span_id` emits exactly 16. Both succeed when `openssl` is absent (shasum fallback path).
- [ ] **AC-3:** `otel_span_sanitize` replaces every comma in its input with a semicolon — byte-identical to the behavior of the former `_telemetry_sanitize`.
- [ ] **AC-4:** When `CCANVIL_TELEMETRY_DISABLED` is set, `otel_span_emit` emits nothing and returns 0; `otel_span_run` still runs its wrapped command and preserves that command's exit code.
- [ ] **AC-5:** Error path — when the OTel Collector is unreachable, `otel_span_emit` returns 0 and never fails its caller (graceful skip, not hard fail).
- [ ] **AC-6:** Given `otel_span_run --service S --name N --category C -- <cmd>`, when invoked, then `<cmd>` runs to completion, one span carrying `duration_ms` and `exit.code` attributes is emitted, and `<cmd>`'s exit code is returned unchanged.
- [ ] **AC-7:** `hub/tests/_helpers/telemetry.bash` sources `otel-span.sh`; its four bats lifecycle functions (`telemetry_setup_file`, `telemetry_teardown_file`, `telemetry_setup`, `telemetry_teardown`) remain defined and callable with unchanged signatures.
- [ ] **AC-8:** Behavior preservation — given the bats suite and `otel-flatten.sh`, when run before and after the refactor, then the set of `(test_name, test_file, test_outcome)` tuples and the set of record keys are identical; only per-run fields (`run_id`, `span_id`, `started_at_unix_nano`, `duration_ms`) differ.
- [ ] **AC-9:** `bats-report.sh`'s suite-root span is emitted via `otel_span_emit` and still carries every `suite.*` attribute and the forced trace/span IDs it carries today.
- [ ] **AC-10:** `otel-span.sh` carries a complete `# @manifest` block and is listed in `.ccanvil/manifest-allowlist.txt`; `module-manifest.sh validate` reports zero drift.
- [ ] **AC-11:** `hub/tests/otel-span.bats` exists, exercises every public function under `--no-telemetry` (no Collector required), and all its tests pass.

## Affected Files

| File | Change |
| -- | -- |
| `.ccanvil/observability/otel-span.sh` | New — generic span helper library |
| `hub/tests/_helpers/telemetry.bash` | Modified — source the helper; thin bats adapters |
| `.ccanvil/scripts/bats-report.sh` | Modified — suite-root span via `otel_span_emit` |
| `.ccanvil/manifest-allowlist.txt` | Modified — add the `otel-span.sh` entry |
| `hub/tests/otel-span.bats` | New test file |

## Dependencies

* **Requires:** the BTS-497 observability stack (`otel-cli`, the OTel Collector) — already present.
* **Blocked by:** nothing. This is the umbrella's foundation child.

## Out of Scope

* Any new span source — scripts, hooks, tool calls (BTS-545 / BTS-547).
* Session-trace correlation (BTS-544).
* Renaming the four bats lifecycle functions — `inject-telemetry-source.sh` hard-codes those names; renaming is explicitly excluded.
* Capturing an `error.excerpt` attribute on script spans — deferred.

## Implementation Notes

* Lift the generic logic verbatim from `telemetry.bash`: `_telemetry_cache_invariants` (git.sha, project root, trace-id generation), `_telemetry_sanitize`, and the `otel-cli span` invocation blocks. ID generation is `openssl rand -hex 16`/`-hex 8` with a `shasum`-based fallback.
* `otel_span_emit` MUST construct a byte-identical `otel-cli` argv to today's inline calls — map every existing flag 1:1. This is what makes AC-8 hold.
* Graceful-skip belongs to `otel-span.sh`. The bats helper KEEPS its existing hard-fail Collector healthcheck (a test run must not run blind) — do not delegate that decision to the helper.
* `_telemetry_compose_attrs` stays in `telemetry.bash` — it is bats-coupled (reads `BATS_TEST_*`). It just calls `otel_span_sanitize` instead of the local copy.
* Manifest: file-level block; `caller:` lists `hub/tests/_helpers/telemetry.bash` and `.ccanvil/scripts/bats-report.sh` only (the post-refactor sourcers).
* The AC-8 byte-identical flatten diff is the load-bearing verification — run it as the acceptance gate, with the "before" baseline captured on `main`.
