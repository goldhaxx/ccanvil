# Implementation Plan: Test Observability — OTel Stack (Foundation)

> Feature: bts-497-test-otel-stack
> Work: linear:BTS-497
> Created: 1778950366
> Spec hash: 4f6c2bf3
> Based on: docs/spec.md

## Objective

Land the runner-neutral OTel observability foundation: bats spans → Collector → Tempo (+ Grafana on port 3001) with deterministic in-the-box flatten, fail-closed healthcheck, schema-versioned per-test JSONL sidecar, and AC-11 config-line visibility.

## Sequence

Steps grouped by phase. Each step is one red-green-refactor cycle (\~5-15 min) unless marked **\[live\]** — those have an explicit live-API verification gate (BTS-171 / `.claude/rules/tdd.md`) that runs an enumerated live command BEFORE commit, not via stubs.

### Phase A — Deterministic foundation (no live deps)

### Step 1: Schema doc — runner-neutral contract (AC-9)

* **Test:** `hub/tests/observability-schema.bats` — `.ccanvil/observability/SCHEMA.md` exists; contains every span attribute from spec §AC-9 Implementation Note + flat JSONL record schema from §AC-10 Implementation Note; both versioned `v1.0.0`; required vs optional marked.
* **Implement:** write `SCHEMA.md` with span schema + flat record schema sections; cite §AC-9, §AC-10, §AC-12.
* **Files:** `.ccanvil/observability/SCHEMA.md` (new), `hub/tests/observability-schema.bats` (new).
* **Verify:** bats green; line counts match expectations.

### Step 2: `.gitignore` for raw-traces artifact (AC-10 prep)

* **Test:** extend Step 1's bats — `.ccanvil/observability/.gitignore` exists and contains `raw-traces.jsonl`.
* **Implement:** write the .gitignore (single-line `raw-traces.jsonl`).
* **Files:** `.ccanvil/observability/.gitignore` (new).
* **Verify:** bats green.

### Step 3: `otel-flatten.sh` core flatten path (AC-10)

* **Test:** `hub/tests/otel-flatten.bats` — given fixture `hub/tests/fixtures/raw-traces-sample.jsonl` (3 spans for `run_id=run-abc`, 2 spans for `run-xyz`), `otel-flatten.sh run-abc` emits 3 flat records to `.ccanvil/state/test-runs.jsonl` matching the AC-10 schema; `run-xyz` records are excluded.
* **Implement:** parse OTLP `ExportTraceServiceRequest` envelopes via `jq`, filter spans by `attributes[].run_id`, emit canonical-keyed JSON via `jq -c -S`.
* **Files:** `.ccanvil/observability/otel-flatten.sh` (new), `hub/tests/otel-flatten.bats` (new), `hub/tests/fixtures/raw-traces-sample.jsonl` (new).
* **Verify:** bats green; output records match schema field-by-field.

### Step 4: `otel-flatten.sh` `(run_id, span_id)` idempotency (AC-12b)

* **Test:** re-running flatten on same input + same `run_id` after first success appends 0 records; sidecar size byte-stable; `wc -l` unchanged.
* **Implement:** before append, build set of existing `(run_id, span_id)` pairs from sidecar; emit only records whose pair is not in the set.
* **Files:** `.ccanvil/observability/otel-flatten.sh` (modified), `hub/tests/otel-flatten.bats` (extended).
* **Verify:** bats green; idempotency test stable across 3 consecutive invocations.

### Step 5: `otel-flatten.sh` fail-closed + sentinel exit (AC-12c)

* **Test:** missing `raw-traces.jsonl` → exit 78 + stderr "ERROR: raw-traces.jsonl not found at <path>"; empty-for-run_id → exit 78 + "ERROR: no spans for run_id=<X>"; malformed JSON → exit 78 + "ERROR: malformed envelope at line <N>".
* **Implement:** add error branches with `exit 78` (sysexits `EX_CONFIG`) and actionable messages.
* **Files:** `.ccanvil/observability/otel-flatten.sh` (modified), `hub/tests/otel-flatten.bats` (extended).
* **Verify:** bats green; all three error paths exit 78 with correct stderr.

### Step 6: Manifest registration (BTS-239 Layer 2)

* **Test:** `bash .ccanvil/scripts/module-manifest.sh validate --json` — coverage `198/198` (was 197 + [otel-flatten.sh](<http://otel-flatten.sh>)); drift `0`.
* **Implement:** add `@manifest` header block to `otel-flatten.sh` (purpose, input, output, depends-on, caller); add path to `.ccanvil/manifest-allowlist.txt`.
* **Files:** `.ccanvil/observability/otel-flatten.sh` (manifest block), `.ccanvil/manifest-allowlist.txt` (modified).
* **Verify:** module-manifest validate clean.

### Step 7: AC-11 — human-stdout config line (`parallel: jobs=N cpus=M wall=Ts`)

* **Test:** `hub/tests/bats-report-stdout-config-line.bats` — `bats-report.sh --parallel` stdout contains a line matching `^parallel: jobs=[0-9]+ cpus=[0-9]+ wall=[0-9.]+s$` IMMEDIATELY above `PASS:`; JSON mode (`--json`) unchanged.
* **Implement:** at `bats-report.sh:393` (just before `echo "PASS: $ok / FAIL: $not_ok / TOTAL: $total"`), emit the config line when `parallel_mode=1` AND output mode is human (not JSON).
* **Files:** `.ccanvil/scripts/bats-report.sh` (modified), `hub/tests/bats-report-stdout-config-line.bats` (new).
* **Verify:** bats green; manually run `bash .ccanvil/scripts/bats-report.sh --parallel hub/tests/idea-add.bats` and confirm visible.

### Phase B — Live stack (live-API gates)

### Step 8: `docker-compose.yml` + Collector skeleton (AC-8) **\[live\]**

* **Test:** `hub/tests/observability-stack-smoke.bats` — `docker compose -f .ccanvil/observability/docker-compose.yml config` exits 0; declared services include `otel-collector`, `tempo`, `grafana`; port mappings match AC-8 (host 3001/3200/4317/4318/13133); bats skips gracefully if `docker` cli absent.
* **Implement:** write compose file with three services + named volumes + bind-mount `.ccanvil/observability/raw-traces.jsonl:/var/lib/otel/raw-traces.jsonl`.
* **Live-API verification BEFORE commit:** `docker compose -f .ccanvil/observability/docker-compose.yml up -d && curl -fsS http://127.0.0.1:13133 && curl -fsS http://127.0.0.1:3001/api/health && curl -fsS http://127.0.0.1:3200/ready` — all must return 200.
* **Files:** `.ccanvil/observability/docker-compose.yml` (new), `hub/tests/observability-stack-smoke.bats` (new).

### Step 9: `otel-collector-config.yaml` — OTLP in + Tempo + fileexporter (AC-1, AC-10) **\[live\]**

* **Test:** smoke bats verifies config validates via `otelcol validate` (containerized); declared pipelines include `traces` with receivers `[otlp]`, exporters `[otlphttp/tempo, file]`.
* **Implement:** OTLP receiver (gRPC 4317 / HTTP 4318), Tempo exporter, `fileexporter` to `/var/lib/otel/raw-traces.jsonl` with `rotation.max_megabytes: 100`, `healthcheckv2extension` at 13133.
* **Live-API verification BEFORE commit:** with stack up, `otel-cli span --endpoint http://127.0.0.1:4318 --service ccanvil-test --name probe --attrs run.id=probe-1,span.id=$(openssl rand -hex 8)` → confirm appears in `raw-traces.jsonl` AND in Tempo query `curl -fsS "http://127.0.0.1:3200/api/search?tags=service.name%3Dccanvil-test"`.
* **Files:** `.ccanvil/observability/otel-collector-config.yaml` (new).

### Step 10: Grafana datasource + Test Runs Overview dashboard (AC-3, AC-4) **\[live\]**

* **Test:** smoke bats verifies datasource YAML declares Tempo at `http://tempo:3200` and dashboard YAML declares the `Test Runs Overview` UID + panels (wall-time time-series, test-count, outcome summary, "Slowest tests across last 7d").
* **Implement:** write provisioning files; reload Grafana on stack restart.
* **Live-API verification BEFORE commit:** `curl -fsS -u admin:admin http://127.0.0.1:3001/api/datasources/name/Tempo` → 200 + UID stable; `curl -fsS -u admin:admin http://127.0.0.1:3001/api/dashboards/uid/test-runs-overview` → 200.
* **Files:** `.ccanvil/observability/grafana/provisioning/datasources/tempo.yaml` (new), `.ccanvil/observability/grafana/provisioning/dashboards/test-runs.yaml` (new).

### Phase C — Helper + integration

### Step 11: `telemetry.bash` helper — healthcheck + span server (AC-2, AC-5) **\[live\]**

* **Test:** `hub/tests/telemetry-helper.bats` — stubbed unreachable Collector → `telemetry_setup_file` exits non-zero with actionable message; stubbed missing `otel-cli` (PATH-shadowed) → exits non-zero with `brew install equinix-labs/otel-cli/otel-cli` hint; happy path → span server pid recorded in `BATS_FILE_TMPDIR/telemetry-pid`.
* **Implement:** mirror manifest-validate-cache.bash pattern. `telemetry_setup_file` does (a) `curl -fsS --max-time 2 "${CCANVIL_TELEMETRY_URL:-http://127.0.0.1:13133}/healthz"`, (b) `command -v otel-cli` check, (c) `otel-cli span background --sockdir "$BATS_FILE_TMPDIR/otel" &`.
* **Live-API verification BEFORE commit:** with stack up, source helper in a one-off test and verify span lands in raw-traces.jsonl.
* **Files:** `hub/tests/_helpers/telemetry.bash` (new), `hub/tests/telemetry-helper.bats` (new).

### Step 12: `telemetry.bash` — attribute resolution (AC-1, AC-6)

* **Test:** parallel-mode env (`PARALLEL_JOBSLOT=7`) → emitted span attrs include `worker.id=7`; single-file mode (unset) → `worker.id=0`; `run.id` = `<epoch>-$$`; `git.sha` = `git rev-parse HEAD` (cached once per file).
* **Implement:** `telemetry_setup` (per-test) composes attribute set from env + cached git sha; helper exposes `_telemetry_emit_span "<outcome>" "<duration_ms>" ["<error_excerpt>"]`.
* **Files:** `hub/tests/_helpers/telemetry.bash` (modified), `hub/tests/telemetry-helper.bats` (extended).
* **Verify:** bats green; AC-6 zero-fallback confirmed.

### Step 13: `bats-report.sh` — invoke `otel-flatten.sh` + exit-code precedence (AC-12d)

* **Test:** `hub/tests/bats-report-otel-flatten.bats` — happy path: bats_rc=0 + flatten ok → exit 0; bats_rc=1 + flatten ok → exit 1; bats_rc=0 + flatten fails → exit 78; bats_rc=1 + flatten fails → exit 78. PASS/FAIL/TOTAL stdout AND `bats-runs.jsonl` envelope show actual bats_rc in all four cases.
* **Implement:** capture `bats_rc=$?` after bats invocation; resolve `run.id` (same epoch-pid used by helper); call `otel-flatten.sh <run_id>`; apply precedence rule; surface flatten failure to stderr.
* **Files:** `.ccanvil/scripts/bats-report.sh` (modified), `hub/tests/bats-report-otel-flatten.bats` (new).
* **Verify:** bats green for all four matrix cells.

### Step 14: `--no-telemetry` escape hatch on [bats-report.sh](<http://bats-report.sh>)

* **Test:** bats — `bats-report.sh --no-telemetry` skips healthcheck precondition AND skips post-run flatten; substrate self-tests can run without the stack.
* **Implement:** flag parsing + conditional path.
* **Files:** `.ccanvil/scripts/bats-report.sh` (modified), `hub/tests/bats-report-no-telemetry.bats` (new).

### Step 15: `cmd_test_suite_run` healthcheck precondition (AC-2)

* **Test:** stubbed unreachable Collector via `CCANVIL_TELEMETRY_URL=http://127.0.0.1:1` → `docs-check.sh test-suite-run` exits non-zero BEFORE bats invocation; with `--no-telemetry` flag, healthcheck skipped.
* **Implement:** insert healthcheck at start of `cmd_test_suite_run` (line 8196); short-circuit on failure.
* **Files:** `.ccanvil/scripts/docs-check.sh` (modified), `hub/tests/docs-check-test-suite-run.bats` (new or extend existing).

### Phase D — Mass rollout (deterministic-first per `.claude/rules/deterministic-first.md`)

### Step 16: `inject-telemetry-source.sh` + drift-guard (AC-7)

* **Test:** drift-guard `hub/tests/telemetry-source-drift-guard.bats` — every `hub/tests/*.bats` file sources `_helpers/telemetry.bash` AND wires `telemetry_setup_file` into a `setup_file()` block; idempotent re-run of injector script produces no diff.
* **Implement:** `.ccanvil/scripts/inject-telemetry-source.sh` (idempotent — marker comment `# bts-497-telemetry-source` keys the insertion site; re-runs no-op when marker present). Execute against all 159 files in one pass. Per `.claude/rules/deterministic-first.md` — this is computable, MUST be a script, not Claude reasoning.
* **Files:** `.ccanvil/scripts/inject-telemetry-source.sh` (new), `hub/tests/*.bats` (159 files, one-line edit each), `hub/tests/telemetry-source-drift-guard.bats` (new), `.ccanvil/manifest-allowlist.txt` (add injector).
* **Verify:** drift-guard green; full suite still passes (re-run after injection).

### Step 17: `manifest-validate-cache.bash` coexistence check

* **Test:** existing BTS-281 cache helper continues to function — no $BATS_FILE_TMPDIR collision with telemetry helper's `otel/` sockdir + `telemetry-pid` files.
* **Implement:** verify helpers compose cleanly. If collision: namespace via subdirs. If no collision: document `<!-- telemetry sourcing pattern -->` block at the top.
* **Files:** `hub/tests/_helpers/manifest-validate-cache.bash` (commented if no behavior change).

### Phase E — Verification + docs

### Step 18: Performance budget verification (AC-7) **\[live\]**

* **Test:** parse last pre-instrumentation row from `.ccanvil/state/bats-runs.jsonl` (the BTS-497 timings snapshot at `bts-497-timings-snapshot-1778897.json` carries baseline p50=83 ms, p95=1075 ms); first post-instrumentation row must be within +50 ms p95 budget.
* **Live-API verification BEFORE commit:** `bash .ccanvil/scripts/bats-report.sh --parallel --timings --json | jq '.metrics.{p50_ms, p95_ms}'` — compute delta vs baseline; assert ≤50 ms.
* **Implement:** no new code; just verification + a budget-check script if useful.

### Step 19: `README.md` operator onboarding + runbook

* **Test:** drift-guard checks sections: `## Quickstart`, `## Start/Stop`, `## Healthcheck`, `## Troubleshooting`.
* **Implement:** write the README — install otel-cli, `docker compose up -d`, view Grafana at [http://127.0.0.1:3001](<http://127.0.0.1:3001>), port allocation table.
* **Files:** `.ccanvil/observability/README.md` (new), drift-guard line in observability-schema.bats.

### Step 20: Full-suite live verification **\[live\]**

* **Live-API verification BEFORE** `/pr`**:** full suite (`bash .ccanvil/scripts/bats-report.sh --parallel`) with stack up — open Grafana dashboard, manually confirm AC-3 (N swimlanes), AC-4 (panels populated), p95 within budget. Visual sign-off captured in PR body.

### Step 21: Hub documentation update (per /plan template step 7)

* **Test:** read-through; no automated gate.
* **Implement:** update `.ccanvil/guide/index.md` (hub) — new section "Test observability" pointing to `.ccanvil/observability/README.md`. Update `CLAUDE.md` hub section — add `docker compose -f .ccanvil/observability/docker-compose.yml up -d` to Commands block. Note `otel-cli` as a new system dep.
* **Files:** `.ccanvil/guide/index.md` (modified), `CLAUDE.md` (hub section modified).

## Risks

* **Live-API contract drift (BTS-171):** Steps 8/9/10/11/18/20 all touch live external systems. Mitigation: each step enumerates the live command set; never commit on stub-pass alone.
* **159-file mass edit fragility:** mitigated by deterministic injector script + drift-guard test + idempotent marker comment (Step 16). If injection corrupts a file, drift-guard catches; revert + fix injector.
* **Performance regression (AC-7 budget):** Step 18 is the gate. If `unix-socket span server` adds >50 ms p95, fall back to direct OTLP per test, OR widen budget by spec-revision (operator decision, NOT silent acceptance).
* **Concurrent-edit on plan Linear Document:** today's session already burned 3 spec overrides. Batch all plan edits locally; dispatch once at /pr time, not after each step.
* **Drift-guard test (**`drift-guard production allowlist clean`**) parallel-12 wall ceiling:** BTS-498 is the optimization. NOT in scope here, but if Step 18 budget fails primarily due to this test, surface it as evidence for BTS-498's priority — not as a BTS-497 blocker.

## Definition of Done

- [ ] All 12 acceptance criteria from spec pass
- [ ] All existing 2,338 tests still pass + new \~6 test files green
- [ ] Manifest coverage = 197 + 2 ([otel-flatten.sh](<http://otel-flatten.sh>), [inject-telemetry-source.sh](<http://inject-telemetry-source.sh>)) = 199/199; drift 0
- [ ] Live Grafana dashboard visually verified (Step 20)
- [ ] Performance delta within budget (Step 18)
- [ ] `/review` run (deterministic + critic agent + security audit per `.claude/skills/review`)
- [ ] Hub documentation updated (Step 21)

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
