# Stasis: session-2026-05-24-bts-544-session-trace-correlation-ship

> Feature: session-2026-05-24-bts-544-session-trace-correlation-ship
> Kind: session
> Last updated: 1779673556
> Session: 74
> Boundary: 2026-05-24T11:15:30-07:00
> Session objective: Ship BTS-544 — Workflow Observability C2 (rooted ccanvil-session trace via SessionStart/SessionEnd hooks).

## Accomplished

* **BTS-544 SHIPPED — PR #196 squash-merged** (`514f13e`; BTS-544 → Done). Workflow Observability C2 of the BTS-542 umbrella. Two new hooks (`session-otel-open.sh`, `session-otel-close.sh`); bats-suite linkage; settings.json wiring; manifests + allowlist; live Tempo verification. All 9 ACs land.
* **Full lifecycle ran end-to-end:** `/idea triage` (cleared BTS-562 + BTS-563 to Backlog P3) → `/spec BTS-544` (validate-clean) → `/spec --review` (caught a unit-of-measure ambiguity: `started_at_unix_nano` → `started_at_epoch` for clock-domain consistency with `otel_span_emit`) → mid-spec scope expansion (operator brought `claude_session_id` in scope as secondary correlation key) → `/spec --review` round 2 (caught hook-chaining model assumption; added Implementation Note) → `/activate` → `/plan` (11 TDD steps) → 10 red-green cycles → `/review` → `/pr` → `/ship 196`.
* **Quality gates:** full bats suite 2572 / 2572 in 365s; manifest 205/205, drift 0; diff-vs-manifest (BTS-268 Layer 3) clean; security audit 0 introduced; live Tempo span verified.
* **Substrate insight:** `claude_session_id` is the FIRST consumer of the SessionStart stdin JSON payload — established the pattern for C5 (per-tool-call instrumentation, BTS-547).
* **Live trace anchored:** `traceID 519cf82d8a119bcd677fb66fff00d4f0` is the BTS-544 acceptance-verification span (rooted `ccanvil-session`, duration 8.6s).

## Current State

* **Branch:** `main` (PR #196 merged + landed; feature branch deleted local + remote).
* **Tests:** full bats suite 2572 / 2572 pass.
* **Uncommitted changes:** none.
* **Build status:** clean. Manifest 205 / 205, drift 0.
* **Linear:** BTS-544 Done. Triage 0. Backlog 79 (includes BTS-562 + BTS-563 from the start-of-session triage).
* **Observability stack:** running; live verification used it (and the next session's `session-otel-open.sh` will fire on startup, writing `.ccanvil/state/session-trace.json`).
* **Context budget:** CRITICAL — 9172 est. tokens vs the 8000 ceiling (115%). Up from 113% — the settings.json grew by \~100 tokens (the two new SessionStart/SessionEnd wirings + the wiring's quoted-string overhead).

## Blocked On

Nothing.

## Next Steps

1. **BTS-545 (C3)** — instrument all 5 deterministic scripts (`module-manifest.sh`, `docs-check.sh`, `ccanvil-sync.sh`, `operations.sh`, `linear-query.sh`) with `otel_span_run` + SCHEMA v1.1.0. Critical path. Next child of BTS-542.
2. **Context-budget trim** — settings.json is now the largest single contributor (\~1639 tokens, 258 lines, 20.5% of the 8000-token ceiling). A trim pass would dent the CRITICAL status. Probably remove stale `permissions` entries or move to `settings.local.json`.
3. **WARN-2 follow-up** (from BTS-544 /review) — document the 2s SessionEnd worst-case latency in the `session-otel-close.sh` comments (Collector-unreachable healthcheck timeout). Tiny doc change; defer to next time the file is touched.
4. **Note:** the next Claude Code session start will be the first real-world exercise of the wired hooks — observe for SessionEnd reliability and whether the reaper safety net fires.

## Context Notes

* **Critic-mode caught TWO load-bearing ambiguities** on a single spec across 2 passes — both real: (1) `started_at_unix_nano` vs `started_at_epoch` unit confusion (10^9 drift if implemented wrong); (2) the unwritten hook-chaining model (shared-fd vs independent fd 0 per hook). Round 2 was triggered by the mid-spec scope expansion (operator added `claude_session_id`). Validates the rule: re-run `/spec --review` after a scope change, even on a previously-clean spec.
* **Linear concurrent-edit guard fired 5×** in the BTS-544 lifecycle (spec dispatch, critic-fix re-dispatch, activate, scope-expansion re-dispatch, Implementation-Notes-addition re-dispatch). Each time: `document-history` empty + `updatedBy == "Zach Wright"` → sanctioned `ALLOW_CONCURRENT_EDIT_OVERRIDE=1`. Already-ticketed as BTS-563 in the start-of-session triage.
* **Drift-guard's @failure-mode / @side-effect markers required a discovery loop.** Adding `@manifest` blocks took 3 validate cycles to fully satisfy the drift-guard — the guard reports a subset of missing markers per pass, not all at once. Future Layer-2 work on hooks: budget 2-3 validate cycles per new hook to converge.
* **AC-7 strict-reading judgment call** — I read "WARN + JSONL when telemetry not live" as "graceful-skip when emission was intended" (so the normal-path open hook stays silent), not as "WARN on every invocation regardless". This means `CCANVIL_TELEMETRY_DISABLED=1` operators get exactly ONE WARN per close hook, ZERO from normal-path open. If too noisy in practice, scope back.
* **Two** `&&` **chains slipped against the documented preference** — `git commit && git push` and `cmd-A && cmd-B`. Auto-mode classifier allowed them (subcommands individually allowed). Behavior-preference, no impact this time.
* **Live-API gate execution** — manually exercised both the normal-close path AND the reaper-on-second-open path against the live Tempo. Both produced expected traces. AC-9 documented as the smoke recipe in `.ccanvil/observability/README.md`.

## Determinism Review

* **operations_reviewed:** \~40 (recall, 2 triage transitions, spec + critic round 1 + critic round 2 + scope expansion, activate, plan, 10 TDD cycles, review + code-reviewer agent + security-audit, full suite, pr-cleanup, push, ship-finalize, 2 live-Tempo smoke probes).
* **candidates_found:** 1.

**concurrent-edit-verify-then-override**: Claude ran the document-history + document-updated-at verification, then ALLOW_CONCURRENT_EDIT_OVERRIDE=1 force-write, FIVE times this session (spec dispatch, critic-fix re-dispatch, activate dispatch, claude_session_id-scope-expansion re-dispatch, Implementation-Notes-addition re-dispatch). The verification is mechanical — `document-history` empty AND `updatedBy` == the caller's own API-key identity means the only diverging edit is the caller's own prior write. artifact-write (or the concurrent-edit guard) could auto-resolve that exact case instead of failing-then-requiring-manual-override each time. Should be substrate logic in `artifact-write` / the concurrent-edit guard. Impact: medium. **Already-ticketed as BTS-563 (created in the start-of-session triage from the BTS-560 prior-session capture); RE-OCCURRED this session 5×, which strengthens the priority case.**

## Evidence Gaps

* BTS-505 — BTS-497 follow-up: capture test.error_excerpt on failed bats spans — missing-evidence-anchors

## Manifest Coverage

205 / 205 (allowlist), drift incidents: 0

## Cross-Session Patterns

* **concurrent-edit-guard friction RECURRED (4th consecutive session).** Last session (BTS-560): 3×. This session (BTS-544): 5×. Ticketed as BTS-563 (priority case keeps getting stronger). The fix is well-specified — the per-session occurrence count is the readout.
* **legacy-refs-scan runtime-artifact false-positive RECURRED (7th consecutive session).** Matches all in `.ccanvil/observability/raw-traces.jsonl` (gitignored OTel runtime artifact; `/catchup` substring inside OTel span names). Already-ticketed as BTS-562. Hub-owned; one-line fix sitting in Backlog.
* **audit-session findings:** 4 pattern matches (curl + jq in the new `.ccanvil/observability/README.md` smoke recipe). False-positive — documentation examples, not stochastic operations.

## Security Review

PASS. The `/review` security-audit reported 17 findings — all pre-existing in files NOT touched by BTS-544 (`docs/sessions/*`, `hub/meta/operations.md`, `docs/specs/bts-72/bts-394/bts-395`). Zero introduced by the BTS-544 changeset (`session-otel-open.sh`, `session-otel-close.sh`, `bats-report.sh`, `session-otel-hooks.bats`, `bats-report-end-to-end-trace.bats`, `settings.json`, `manifest-allowlist.txt`, `observability/README.md` carry no secrets, PII, or credentials).

## Memory Candidates

1. **Drift-guard convergence pattern** — adding `@manifest` blocks to new files requires multiple validate-and-fix cycles; the guard surfaces a subset of missing markers per pass (failure-mode markers first, then side-effect markers). Budget 2-3 cycles per new primitive in future Layer-2 rollouts. Candidate for a `reference` memory (substrate behavior).
2. **claude_session_id correlation pattern** — the SessionStart hook stdin JSON payload's `.session_id` field is the Claude Code session UUID; carrying it as a `claude_session_id` span attr (with omit-when-empty semantics) creates a pivot key from Claude-side logs to ccanvil's Tempo traces. The hook-chaining model assumption (independent fd 0 per hook) is the load-bearing prerequisite; AC-2's empty-fallback covers the shared-fd failure mode. Candidate for a `project` memory (will recur in C5 / BTS-547).
3. **Workflow Observability C2 SHIPPED** — update the umbrella project memory (\[\[workflow-observability-umbrella\]\]) with C2 done + the env-leak lesson (still applicable for C3/C5) + the AC-7 strict-reading interpretation (loud-WARN on telemetry skip).