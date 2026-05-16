# Stasis: session-2026-05-16-bts-497-foundation-ship

> Feature: session-2026-05-16-bts-497-foundation-ship
> Kind: session
> Last updated: 1778968492
> Session: 57
> Boundary: 2026-05-16T09:23:46-07:00
> Session objective: Take BTS-497 (test-observability OTel stack foundation) end-to-end from spec critic-review → activate → 21-step plan → 5-phase implementation (deterministic foundation → live stack → helper + integration → narrowed Phase D sample → docs) → /review → /pr → /ship. Capture follow-up tickets for the 149-file rollout, error_excerpt capture, and stack-state surfacing.

## Accomplished

Session 57 was a single-feature-end-to-end ship of BTS-497 — the largest single-feature delivery this project has had. The Stage 1 ccanvil-self test-observability stack is live, merged to main, and BTS-497 is closed in Linear. 18 feat commits + 2 docs + 1 lifecycle + 1 research, 22 commits ahead of session-55's anchor.

* **/spec --review iterations (4 passes).** Critic-mode pre-flight caught three load-bearing semantic ambiguities before code shipped:
  * P1: AC-10 emission-path was ambiguous (Collector fileexporter raw output vs flatten step) — pinned the exact pipeline path + 11-field schema.
  * P2: AC-12 idempotency key was ambiguous (byte-identity vs semantic) — pinned `(run_id, span_id)` with span_id = OTel-spec 16-hex unique identifier.
  * P3: AC-12 exit-code precedence when bats already failed (OR vs sentinel) — pinned sentinel exit 78 (sysexits EX_CONFIG) always overrides bats_rc; bats_rc preserved in stdout PASS/FAIL + bats-runs.jsonl envelope.
  * P4: PASS. Spec validated semantically, not just structurally.
* **/activate → /plan → 5-phase implementation.** 21-step plan, narrowed to \~18 actually executed once Phase D scope was scoped down. Each phase delivered:
  * **Phase A (Steps 1-7) — deterministic foundation:** SCHEMA.md v1.0.0 (12 tests), .gitignore, [otel-flatten.sh](<http://otel-flatten.sh>) (TDD'd against fixture: AC-10 core path + AC-12b (run_id, span_id) idempotency + AC-12c fail-closed sentinel 78), BTS-239 manifest registration (198/198 198/198), AC-11 human-stdout config line in [bats-report.sh](<http://bats-report.sh>).
  * **Phase B (Steps 8-10) — live stack \[live\]:** docker-compose.yml (Collector + Tempo + Grafana on 127.0.0.1 loopback), otel-collector-config.yaml (health_check extension, OTLP receivers, Tempo + fileexporter), Grafana datasource auto-provisioning + Test Runs Overview dashboard (4 AC-4 panels). Live verified: span round-trip raw-traces.jsonl + Tempo `/api/traces/<id>` + [otel-flatten.sh](<http://otel-flatten.sh>) end-to-end.
  * **Phase C (Steps 11-15) — helper + integration:** telemetry.bash (AC-2 healthcheck + AC-5 otel-cli check + AC-6 PARALLEL_JOBSLOT=0 fallback + AC-1 8-attribute set), [bats-report.sh](<http://bats-report.sh>) integration (post-run flatten + AC-12d exit-78 precedence + --no-telemetry escape hatch), cmd_test_suite_run AC-2 dispatcher precondition. Major substrate-misuse pivot in Step 12.
  * **Phase D (Step 16, narrowed) — 10-file sample:** Wired helper into 10 representative bats files spanning 6 setup-pattern categories (A: no setup → F: setup_file + teardown_file only). 91 tests → 91 spans → 91 flat JSONL records end-to-end live verified. Comma-sanitization fix caught dropping 8/91 spans pre-fix.
  * **Phase E (Steps 17-21, partial) — verification + docs:** README operator runbook (Quickstart + Start/Stop + Healthcheck + ports + opt-out + troubleshooting), `.ccanvil/guide/index.md` link, `CLAUDE.md` Tech Stack + Commands updates. Steps 18+20 (AC-7 perf budget + full-suite Grafana visual sign-off) deferred to BTS-504 ramp (narrowed scope can't measure full-suite delta meaningfully).
* **/review (commit aa70b1a) — 4 CONCERNS + 2 INFO, all fixed:**
  * C1 manifest drift on [bats-report.sh](<http://bats-report.sh>) (Layer 3 manual gate caught new code-side markers without header declarations) → header now declares the new failure-mode + side-effect + flag + 3 env-var inputs + contract + BTS-497 anchor.
  * C2 BATS_TEST_ERROR_EXCERPT phantom var (helper read a non-existent bats env var) → pass empty literal + inline comment + BTS-505 follow-up captured.
  * C3 raw-traces.jsonl first-run footgun (Docker auto-creates source as directory if absent) → README quickstart touch step + [otel-flatten.sh](<http://otel-flatten.sh>) pre-flight that exits 78 with explicit fix recipe.
  * C4 SCHEMA/code divergence on duration_ms → SCHEMA.md relaxed to "optional" matching code behavior.
  * INFO A + B: stale spec text (otel-cli span background reference) + misleading test name (healthcheckv2 → health_check) — both fixed.
* **/pr — 2,425/2,425 PASS after AC-29 allowlist fix.** Full suite wall 425s (parallel-12) including the BTS-281 pre-warm + 5.5-min drift-guard outlier. One failure (AC-29 grep guard) caught a missed allowlist entry for the BTS-497 timings snapshot — fixed in 5 lines.
* **/ship 188 — squash-merged, BTS-497 In Progress → Done, branch deleted, HEAD back on main.** Ship-finalize substrate ran clean: title verified, gh pr merge --squash --delete-branch, cmd_land, AUTO-CLOSE dispatched.
* **3 follow-up tickets captured during the session:**
  * **BTS-504** — full bats rollout (\~149 remaining files). Deterministic injector script handling all 6 setup-pattern categories. Wires telemetry helper at scale.
  * **BTS-505** — `test.error_excerpt` capture on failed bats spans. Bundles with BTS-504's injector pass (per-test stderr wrap).
  * **BTS-506** — stack-state surfacing in /radar + `docs-check.sh observability {status,up,down,restart,logs}` substrate verbs. Bundles with BTS-504 (when stack becomes load-bearing for every run).
* **Six substrate-misuse incidents caught + fixed mid-flight:**
  1. `otel-cli span background` is NOT a multi-span daemon (it's a single long-running span you add events to). Spec + plan both assumed wrong. Pivoted to direct OTLP HTTP per test (\~5-15 ms vs phantom 1-3 ms socket). 21-min hung-bats-teardown incident before catch.
  2. BTS-281 module-manifest pre-warm in [bats-report.sh](<http://bats-report.sh>) adds \~7 min to any test that invokes the script — stubbed via BTS_MANIFEST_VALIDATE_CACHE env var in 3 new test files (forgot twice before establishing the pattern).
  3. `otel-cli --attrs` is comma-delimited with no escape mechanism. Bats test names commonly contain commas (`{action, command, reason}`). 8/91 spans silently dropped pre-fix. Added `_telemetry_sanitize()` helper.
  4. `healthcheckv2` extension isn't in contrib 0.117.0. Pivoted to v1 `health_check` (port + contract unchanged, name only).
  5. `BATS_TEST_ERROR_EXCERPT` was a phantom env var. bats 1.13.0 doesn't expose structured fail-message to teardown. /review caught this; pass empty literal + BTS-505 follow-up.
  6. `raw-traces.jsonl` bind-mount footgun. Docker auto-creates the source as a DIRECTORY if absent. Pre-flight added.

## Current State

* **Branch:** `main` (post-ship, clean)
* **Tests:** 2,425/2,425 PASS, wall 425.3s parallel-12 (last run at /pr step — same run state as ship)
* **Uncommitted changes:** none
* **Build status:** clean. Manifest 198/198, drift 0 (confirmed at commit aa70b1a and stable through ship — no manifest-tracked files modified after).
* **Backlog:** 41 Backlog + 12 Triage. New this session: BTS-504, BTS-505, BTS-506.
* **OTel stack:** still running (`docker compose ps` would show 3 containers up). Operator-managed manually; BTS-506 will surface state in /radar in a future ship.

## Blocked On

Nothing.

## Next Steps

1. `/idea triage` — 12 Triage items including this session's 3 new captures (BTS-504/505/506). Worth a clearing pass.
2. BTS-504 is the natural next BTS-497-cluster ship — full bats helper rollout via deterministic injector. Bundles BTS-505 (error_excerpt capture wrapping) + BTS-506 (stack-state surfacing in /radar) per the dependency notes in each ticket body.
3. BTS-498 (drift-guard 5.5-min outlier) is an independent ship that complements BTS-497. Highest single-test wall-time savings in the suite.
4. **Roadmap re-anchor.** Active theme on roadmap is still "Dark Code / Three-Layer Solution" but the BTS-497 ship pivots the next-up theme to **test observability**. Worth a roadmap update.
5. The OTel stack is still running. `docker compose -f .ccanvil/observability/docker-compose.yml down` when the operator wants to free the \~700 MB RAM. No automated teardown.

## Context Notes

* **Phase D narrowing was the right call.** Full 159-file mass edit had three failure modes (Cat A-F injector regex bugs, BTS-281 pre-warm trap multiplication, drift-guard 5.5-min wall multiplied per iteration). Narrowing to 10 representative files captured the wiring pattern proof + caught the comma-sanitization bug at sample scale (would have been 100+ silently-dropped spans at full scale). BTS-504 inherits a proven template.
* **The /review pass paid off.** Four CONCERNS landed real fixes that would have shipped silent bugs: phantom env var (broken contract for failed spans), bind-mount footgun (fresh-clone trap), schema/code divergence (downstream contract), manifest drift (lost contract description). The reviewer also caught the misleading test name + stale spec text. Memory: critic-mode catches different gaps than validate-spec; the two are complementary, not redundant.
* **Substrate primitives need empirical pre-checks before scaling integration.** The `otel-cli span background` misuse cost 21 min of hung-bats time + a partial-implementation rewrite. A single one-line experiment (run `otel-cli span background --sockdir /tmp/test &; ls /tmp/test` to see what files it creates) would have caught the wrong-primitive assumption in seconds. Memory candidate: "before wiring an external substrate primitive into N test files / pipelines, run one quick empirical check on what it actually does — the docs may not match runtime."
* **Auto-mode classifier blocked concurrent-edit override 3 times this session.** Each required AskUserQuestion-based per-instance authorization. Operator authorized every time. Pattern: in long spec-iteration sessions on Linear-routed nodes, the classifier fires at the 2nd+ force-write. Worth a memory: when operator pre-authorizes a session's critic-iteration arc, the per-instance gates are friction without proportional value. (No clean workaround; the classifier is independent of session-scope decisions.)
* **Operator's "what's the teardown" question revealed a workflow gap.** The README documents `docker compose down` but doesn't surface it actively. The stack's persistence is an architectural choice (avoid 25s warm-up between iterations) but the operator-awareness side is a real UX gap. Captured as BTS-506.
* **Phase D wiring template per category (proven, ready for BTS-504 injector):**
  * **Cat A (no setup):** source helper + 4 lifecycle functions at top.
  * **Cat B (setup only):** source + 3 functions; append `telemetry_setup` to existing setup body.
  * **Cat C (setup + teardown):** source + 2 functions; append telemetry_setup; PREPEND telemetry_teardown to teardown body (so bats state vars are pristine).
  * **Cat D (Cat C + load helper):** same as Cat C; `load` directive doesn't conflict.
  * **Cat E (setup_file + setup + load helper):** PREPEND telemetry_setup_file to setup_file body (healthcheck before expensive init); append telemetry_setup; add teardown_file + teardown if missing.
  * **Cat F (setup_file + teardown_file only):** source + setup + teardown new; prepend telemetry_setup_file; APPEND telemetry_teardown_file.
* **The Stage 1 / Stage 2 framing held.** Helper is runner-neutral by construction — span schema is OTel-standard, attribute set matches the SCHEMA.md v1.0.0 contract. BTS-499 (Stage 2 distillation) can extend to pytest/vitest/go without re-derivation. The 10-file sample exercises the contract; the helper has no bats-specific assumptions beyond `BATS_TEST_DESCRIPTION` (which downstream runners replace with `__name__` / `it.name` / etc).

## Determinism Review

operations_reviewed: 21
candidates_found: 1

* **bats-report-stub-pattern-codification**: Claude wrote 3 new bats files this session that invoke `bats-report.sh` (bats-report-stdout-config-line, bats-report-otel-flatten, bats-report-no-telemetry, docs-check-test-suite-run-healthcheck). Each required setting `BTS_MANIFEST_VALIDATE_CACHE` env var to stub the BTS-281 pre-warm — otherwise each invocation pays a \~7-min toll. I forgot the stub twice this session (hung the bats run by \~28 min once before catch). Pattern: any test that invokes [bats-report.sh](<http://bats-report.sh>) in a subshell falls into the same trap. Should be a shared `_helpers/bats-report-stub.bash` with a `stub_bats_report_prewarm()` helper that future tests source — eliminates the trap entirely. Impact: medium — every BTS-504 follow-up bats file faces the same risk; the existing pre-existing tests (4 of them) coexist with the trap because they were written when the pre-warm was newly added and the pattern was well-known. Determinism candidate because a shared helper is the right substrate shape (mechanical replacement for hand-managed pattern memorization).

## Evidence Gaps

* BTS-505 — BTS-497 follow-up: capture test.error_excerpt on failed bats spans — missing-evidence-anchors

The evidence-gap scanner flagged BTS-505 because the body uses bug-shape language ("doesn't expose", "phantom variable") without the 4 evidence anchors (`Command:`, `Output:`, `Exit:`, `Reproduce:`). BTS-505 is actually a substrate-feature-gap ticket, not a fix-shape capture — the existing code WORKS (helper emits spans), the gap is that error_excerpt is never populated on failed spans. The bug-shape regex catches the wording, not the shape. Per the rule, the operator can either (a) add evidence anchors to BTS-505's body (the "phantom variable" is reproducible via `grep -rn BATS_TEST_ERROR_EXCERPT hub/tests/` returning the one usage in telemetry.bash with no other definition) or (b) retitle as `DIAGNOSE: error_excerpt never populated on failed bats spans` to make the diagnostic-shape explicit. Either reshape is fine; the work is correct as-spec'd.

## Manifest Coverage

198 / 198 (allowlist), drift incidents: 0

Skipped the redundant validate at /stasis time per operator pushback — last validated clean at commit `aa70b1a` (the /review fixes). Files modified after that point: hub/tests/legacy-refs-allowlist.txt (not allowlisted), docs/spec.md + docs/plan.md + docs/stasis.md (removed; not allowlisted), `docs/sessions/*.md` (archive snapshots; not allowlisted), merge commit (no new content). Manifest state is provably unchanged.

## Cross-Session Patterns

* **Auto-mode classifier blocks concurrent-edit override pattern recurred a 4th time this session** (sessions 54 → 55 → 57). Three forced authorizations during /spec critic-mode iterations on the BTS-497 Linear Document. The pattern is now a confirmed recurring friction in long spec-iteration sessions on linear-routed nodes. Memory candidate (promote to memory this session — third confirmation passes the threshold).
* **BTS-281 pre-warm trap recurred** — I hit it twice in one session (Step 7's bats-report-stdout-config-line.bats, then again at Step 13 when I noticed it had been working for Step 13 but ran the regression that also included Step 7's file). Each occurrence cost \~7-28 min wall time. Same pattern as the determinism candidate above.
* **legacy-refs-scan**: `[]` (empty, clean — AC-29 allowlist fix in `259dfa5` handled the BTS-497 timings snapshot pattern).
* **audit-session**: 9 patterns (8 jq + 1 curl) — all expected substrate uses in the new bats tests and [otel-flatten.sh](<http://otel-flatten.sh>). Not findings.

## Security Review

PASS. New code in this session touches: telemetry.bash helper, [otel-flatten.sh](<http://otel-flatten.sh>), docker-compose.yml + 2 supporting YAMLs + 1 dashboard JSON, observability README + SCHEMA, bats tests, modifications to [bats-report.sh](<http://bats-report.sh>) + [docs-check.sh](<http://docs-check.sh>), CLAUDE.md + guide index. All grep-checked for secret patterns: zero hits. Docker-compose ports all `127.0.0.1:`-bound (loopback only). Grafana admin/admin credentials documented in README as appropriate for local-only loopback service. No tokens, no API keys, no PII beyond the operator's already-pre-existing absolute-home-paths in unrelated docs files. [Security-audit.sh](<http://Security-audit.sh>) --files-only summary: 1 CRITICAL + 6 HIGH + 10 MEDIUM, all pre-existing on main (verified `git diff main...HEAD` shows none of the flagged files modified this branch).

## Memory Candidates

* **auto-mode-classifier-multi-write-pattern** — confirmed across 3 sessions now (54, 55, 57). Worth promoting to memory: "In long spec-iteration sessions on Linear-routed nodes, the auto-mode classifier blocks force-overrides of the concurrent-edit guard after the first per-instance authorization. Pre-warn the operator at session start when planning N rounds of spec critic-mode, or expect N AskUserQuestion interrupts."
* **substrate-primitive-empirical-precheck-before-scaling** — new this session. "Before wiring an external substrate primitive (`otel-cli span background`, `pio_certifi`, similar) into N test files or pipelines, run one quick empirical experiment to confirm the primitive does what the docs/spec assume. Docs lie; runtime is authoritative. 60 seconds of empirical check at design time saves hours of debugging at integration time. BTS-497 origin: 21-min hung-bats incident from misreading otel-cli's `span background` verb."
* **otel-cli-attrs-comma-delimited-sanitize** — new substrate-specific reference. "otel-cli's `--attrs` flag is comma-delimited with no escape mechanism. Bats test names commonly contain commas (`AC-1: every state has {id, description}`); unsanitized commas silently drop the span. Always sanitize commas (replace with `;`) in string-valued attributes before passing. Anchored in telemetry.bash's `_telemetry_sanitize()`."
* **phase-d-narrowed-scope-decision** — operator-validated pattern. "When a planned step has full-N risk profile (N file edits with potential silent corruption, multiplied debug cycles, etc.), narrow scope to a representative sample spanning all relevant categories + capture follow-up. Operator validates the call when the narrowing names categories explicitly. BTS-497 Phase D = 10 of 159 files, 6 categories proven, BTS-504 captured for rollout."
* **bats-report-stub-pattern** — new feedback/reference. "Any bats test that invokes `bats-report.sh` in a subshell pays the BTS-281 module-manifest pre-warm (\~7 min per call) unless `BTS_MANIFEST_VALIDATE_CACHE` env var is stubbed. Always stub in setup(). Stubs at:

  ```
  local stub_cache=\"\$BATS_TEST_TMPDIR/manifest-cache.json\"
  echo '{\"coverage\":{\"covered\":0,\"total\":0},\"drift\":[],\"status\":\"ok\"}' > \"\$stub_cache\"
  export BTS_MANIFEST_VALIDATE_CACHE=\"\$stub_cache\"
  ```

  Pending substrate fix per BTS-504 / BTS-506-adjacent: shared `_helpers/bats-report-stub.bash` helper."
* **lifecycle-running-services-need-active-resurfacing** — new feedback. "Long-lived dev services (the OTel stack, drift-watchdog launchd, future BTS-500/501 layers) need active resurfacing in the operator's regular awareness flow (/radar, /recall) — otherwise the operator forgets they exist. README documentation is necessary but not sufficient. BTS-506 ships the /radar integration for the OTel stack; pattern applies to future long-lived services."

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->