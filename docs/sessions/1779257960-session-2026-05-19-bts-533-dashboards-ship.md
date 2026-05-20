# Stasis: session-2026-05-19-bts-533-dashboards-ship

> Feature: session-2026-05-19-bts-533-dashboards-ship
> Kind: session
> Last updated: 1779257960
> Session: 67
> Boundary: 2026-05-19T17:58:29-07:00
> Session objective: Fix the BTS-533 "weird open kinks" in the test-observability dashboards so they display what they should, then ship — bundled into the open BTS-504 PR per operator decision.

## Accomplished

* **BTS-533 dashboard polish shipped — PR #192 MERGED** (squash commit `42833a5`; BTS-504 Linear ticket auto-closed). The dashboard work was bundled onto the in-flight BTS-504 branch per the operator's explicit "keep 192 open, bundle, ship when complete" decision.
* **Consolidated dashboard** — `ccanvil-test-observability.json` (NOW / SLOW / DIDN'T PASS / TREND sections) replaces the two prior dashboards (`test-runs-overview.json` + `test-runs-live.json`, both deleted).
* **Refresh-stability fix** — TraceQL `limit` truncates an *unstable subset* during Tempo's streaming block-merge (not a global-sorted top-N). Panels now use `limit: 500` (full set, no truncation → stable) + `sortBy` transformations with `Span ID` as a deterministic secondary key. Verified stable across 20+ refreshes.
* **Trace Name vacillation fix** — `Trace Name` / `Trace Service` columns hidden. Tempo's computed `rootTraceName` is non-deterministic for all-orphan traces (e.g. trace `6e65ed7f...` = 2491 rootless spans from a pre-hierarchy BTS-504 run) and for block-fragmented traces. The dashboard no longer depends on `rootTraceName`.
* `otel-flatten.sh` **exit-78 regression fixed** — BTS-504 suite-root spans carry `run.id` but no `worker.id`; `worker.id | tonumber` aborted the whole flatten on `null`, surfacing as `bats-report.sh` exit 78 (would have blocked the `/pr` gate). Fix: skip non-test spans (`select($attrs["test.name"] != null)`). Regression test + `raw-traces-hierarchy.jsonl` fixture added.
* `telemetry.bash` — `test.file` now anchored on `BTS_TELEMETRY_PROJECT_ROOT` (git toplevel, cached once per file) so paths stay repo-relative even when a test `cd`s without restoring.
* **6 env-dependent test failures fixed** (not skipped) — `bats-report-perf-core-default.bats` + `bats-report.bats` stub-run invocations got `--no-telemetry`; the failure was the flatten step erroring with no spans to flatten.
* **AC-29 grep guard** — added `--exclude-dir=state` (caught in-flight by the `/pr` pre-merge gate; symmetric with the existing `observability` exclusion).
* **README** — added "Reading the dashboard" + Tempo query-mode guide + troubleshooting for all three footguns.

## Current State

* **Branch:** `main` (PR #192 merged + landed; feature branch deleted local + remote)
* **Tests:** full suite ran as the `/pr` pre-merge gate — 2524 pass / 1 fail / 2525 total; the lone failure (AC-29 guard false-positive) was fixed in-flight (`7b3424d`) before merge. Affected-file targeted runs all green post-fix.
* **Uncommitted changes:** none
* **Build status:** clean. Manifest 202/202, drift 0 (cached at `cff3785` per `test-state`; the squash-merge added only a test-file change since, nothing manifest-tracked).
* **Linear:** BTS-504 closed; BTS-533 still open (tracks the one deferred item — see Next Steps).
* **Observability stack:** running; dashboard `ccanvil-test-obs` provisioned + verified live.

## Blocked On

Nothing.

## Next Steps

1. **BTS-533 issue #4 — 99% span propagation** (operator explicitly deferred to a future session). The earlier 2493/2519 gap (\~26 tests with no span) needs a full-suite run to re-measure, then a decide: accept 99% as a documented limitation OR investigate stderr-capture wrapping. BTS-533 stays open in Linear as the tracker for this.
2. **BTS-498 — drift-guard 5.5-min optimization.** Now plainly visible: `module-manifest-drift-guard.bats` is the dominant bar in the dashboard's "Slowest files" panel (\~4.9 min).
3. **BTS-511 — test-discipline rule enforcement** (3 evidence items, ready when capacity returns).
4. **1 untriaged idea** — run `/idea triage`.

## Context Notes

* **TraceQL** `=~` **/** `!~` **are full-line implicit-anchored.** `name =~ "^bats suite"` NEVER matches — the leading `^` is treated literally inside an already-anchored match. Use `name =~ "bats suite.*"`. A smoke-test guard (`observability-stack-smoke.bats` AC-4) now enforces this; note the guard's own jq regex needs exactly 2 source backslashes (`\\^`), not 4 — the code-reviewer caught a 4-backslash version that was a silent no-op.
* **TraceQL** `limit` **is applied during a streaming block-merge, not after a global sort.** When matches exceed `limit`, each search returns a different arbitrary subset. Size `limit` above realistic match volume (panels use 500) so the full set always returns.
* **Tempo** `rootTraceName` **is unreliable** for traces with no clean single root (all-orphan, or fragmented across many blocks — our 30s `max_block_duration` tuning fragments long suite traces). Dashboards must not surface it.
* **BTS-281 manifest pre-warm (\~7 min)** runs before any test span emits and dominates every suite trace's wall-time — a 5s test run shows as "7+ min". Not a dashboard bug (the dashboard honestly shows emitted spans) but it's the biggest drag on the live-feed "watch tests roll in" experience. Candidate follow-up: emit a pre-warm span so the waterfall shows it explicitly, or optimize the pre-warm.
* **All three dashboard footguns were surfaced by the operator's manual refresh-testing**, not by automated checks — the operator ran 10-20 refreshes and watched columns. Dogfood-probe pattern held again.

## Determinism Review

* **operations_reviewed:** \~14 (dashboard JSON edits, Tempo API probes, browser refresh-stability verification, otel-flatten diagnosis, bats targeted + full-suite runs, git ship workflow, README edits, code-review gate).
* **candidates_found:** 0.

No candidates this session. The work was bug investigation (three distinct dashboard root-causes, each needing judgment) plus config/code fixes. The dashboard JSON, `otel-flatten.sh` filter, and `telemetry.bash` anchor ARE the deterministic substrate — they are shipped code, not session-bounded heuristics. The browser refresh-stability checks were one-off verification, not a recurring op worth scripting.

## Evidence Gaps

No evidence gaps this session.

## Manifest Coverage

202 / 202 (allowlist), drift incidents: 0

(Cached at `cff3785a25ea54f646dd6e681acab19818034b2c` per `test-state` — the squash-merge to `42833a5` added only `hub/tests/stasis-recall.bats` (a test file, not manifest-tracked) since that validate.)

## Cross-Session Patterns

* `legacy-refs-scan` **substrate gap — RECURRING (3rd session running).** The scan still flags `.ccanvil/observability/raw-traces.jsonl` (a gitignored runtime artifact) for `checkpoint`/`catchup` strings inside test-span names. Prior stasis flagged "should add `--exclude-dir=observability` to legacy-refs-scan too" — still not done. This session the *analogous* AC-29 guard in `stasis-recall.bats` needed `--exclude-dir=state` (fixed in `7b3424d`). The `legacy-refs-scan.sh` script itself still excludes neither `observability/` nor `state/`. Hub-owned substrate gap — worth a dedicated capture; the runtime-artifact-dir exclusion list should be shared, not re-derived per guard.
* **Scope-up-on-reveal fired again** — the AC-29 guard fix surfaced mid-`/pr` (the pre-merge gate caught it); the caret-regex no-op surfaced in the code-review gate. Each mid-flight discovery was absorbed before merge rather than deferred. Healthy; matches the established pattern.

## Security Review

PASS. The `/review` security audit reported 17 findings — all pre-existing in files NOT touched by this changeset (`docs/sessions/*`, `docs/specs/*`, `hub/meta/operations.md`). Zero introduced by the BTS-533 diff. The changeset itself (dashboard JSON, `otel-flatten.sh`, `telemetry.bash`, bats files, README) carries no secrets, no PII, no network egress beyond the localhost Tempo/Collector endpoints.

## Memory Candidates

1. **Tempo / TraceQL behavioral gotchas** — three non-obvious facts surfaced this session (`=~` implicit-anchoring, `limit` streaming-truncation, `rootTraceName` instability). All three are now documented in `.ccanvil/observability/README.md` (Troubleshooting + "Reading the dashboard"). Worth a *reference* memory pointing at that README section so future observability work knows where the gotcha catalog lives — content is in the doc, the memory is just the pointer.
2. `legacy-refs-scan` **runtime-artifact-dir gap** — recurring across 3 sessions; the scan needs `observability/` + `state/` exclusions. Not a new memory (it's a backlog item), but the cross-session recurrence is itself the signal that it should be captured as a real ticket rather than re-noted each stasis.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->