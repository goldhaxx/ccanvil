# Stasis

> Feature: session-2026-04-27-stabilization-drained-darkcode-rollover
> Kind: session
> Last updated: 1777345200
> Session: 9
> Boundary: 2026-04-27T18:12:29-07:00
> Session objective: drain the entire backlog under the Stabilization & Maturation theme, then evaluate next-theme rollover. Started with 13 backlog + 2 triage; ended with 0/0 + theme rollover to Dark Code.

## Accomplished

* **9 ships in one turn — record cadence** (BTS-215, 238, 237, 207, 211, 236, 209, 208, 183 in dispatch order):
  * **BTS-215** (PR #129) — `docs-check.sh` usage string generated from dispatch table at runtime. Drift-guard test enforces by construction. 25 to 51 verbs surfaced.
  * **BTS-238** (PR #130) — `cmd_stasis_carry_forward` regex-escape gsub fix. Named-capture pattern + corrected replacement. Live-API gate proved on existing BTS-237 dual-capture.
  * **BTS-237** (PR #131) — spec/activate concurrent-edit race fix. `cmd_artifact_write` skips `_doc_cache_set_updated_at` on CREATE path; UPDATE path still caches. Eliminates the 8x-per-session manual `ALLOW_CONCURRENT_EDIT_OVERRIDE=1` retry. **Live AC-5 proved on the very next ship** (BTS-207 activate ran clean).
  * **BTS-207** (PR #132) — `cmd_session_info` collapsed from 5 jq forks to 1 via `--rawfile` + `try ($raw | fromjson) catch ...`. Path-shadow counted-jq test pattern.
  * **BTS-211** (PR #133) — `operations.sh exec` now eval's both bash AND http mechanism resolutions (case branch swap). mcp continues to echo envelope. Live-API gate verified `backlog.list | jq '.[].id'` round-trips.
  * **BTS-236** (PR #134) — derive-pr-title structural pivot. `cmd_stamp_spec` auto-inserts `> Subject:` from H1; `cmd_derive_pr_title` reads it first. Closes the truncation class. **Live AC-9 proved on every subsequent ship** — PR titles clean ≤72 chars from BTS-209 onward.
  * **BTS-209** (PR #135) — canonical hook failure recording. New `_hook_record_failure` helper at `.claude/hooks/_lib/record-failure.sh`; both telemetry hooks (post-compact-marker, session-boundary) migrated to per-step guards + durable JSONL log at `.ccanvil/state/hook-failures.log`.
  * **BTS-208** (PR #136) — hook timing instrumentation. `_timer_start`, `_timer_duration_ms`, `_timer_emit` helpers in same `_lib`. Both telemetry hooks emit duration_ms to `.ccanvil/state/execution-timing.log`. macOS `%3N` to python3 to seconds\*1000 fallback chain.
  * **BTS-183** (PR #137) — provider integration strategy. New `.claude/rules/provider-integration.md` codifies http-canonical for substrate, MCP for operator-tools. Swept 6 dead-code MCP verbs (idea.{promote,defer,dismiss,merge}, backlog.get, ticket.find-by-title) — \~200 LOC removed from [operations.sh](<http://operations.sh>), 35 dead-verb tests deleted, `hub/tests/ticket-find-by-title.bats` removed entirely.
* **7 drift-watchdog tickets canceled** (BTS-191 through BTS-197) — operator-stated dormant downstream nodes; no syncs planned during ccanvil-focus phase.
* **2 captures triaged + promoted** — BTS-236 + BTS-237 to Backlog P3 at session start. **1 capture surfaced + shipped** — BTS-238 captured during recall-dogfood (gsub regex-escape false-positive on BTS-237's slug), promoted, shipped same turn.
* **Theme rollover**: Stabilization & Maturation to Dark Code / Three-Layer Solution. Roadmap rewritten; 14-day soak window replaced with live-throughput guard (>2 captures/week = signal stabilization didn't hold, pause and re-stabilize).

## Current State

* **Branch:** `main`, fast-forwarded to origin (commit `1eee0c8`). Working tree clean.
* **Tests:** **1839 / 1839 passing**. Net delta from session start: 1826 to 1839 (+13). Mid-session peak was 1874 (after BTS-208); BTS-183 sweep removed 35 dead-verb tests for net +13.
* **Uncommitted changes:** none.
* **Build status:** clean.
* **Backlog: 0 / Triage: 0 / Icebox: 2** (BTS-22 docs directory + BTS-21 GitHub agentic workflows — long-tail research, deferred).

## Blocked On

Nothing.

## Next Steps

1. **Begin Dark Code Phase 1 — research lap.** Read the Nate B Jones video transcript end-to-end ([https://www.youtube.com/watch?v=E1idsrv79tI](<https://www.youtube.com/watch?v=E1idsrv79tI>)). Map the three layers to ccanvil's current shape:
   * Layer 1 (Spec-Driven Development) — assess where the existing spec to plan to impl flow leaks.
   * Layer 2 (Self-Describing Systems) — biggest current gap. What would a module manifest look like for substrate primitives like `cmd_artifact_write`, `cmd_ship_finalize`, `cmd_idea_pending_replay`?
   * Layer 3 (Comprehension Gate) — how does this interact with code-review and the code-reviewer agent? Before-spec, before-merge, or both?
     Output: research note at `docs/research/dark-code-mapping.md` with one section per layer.
2. **Spec the first ship.** Likely Layer 2 — module manifests for \~3 seed substrate primitives. Open question: in-source comment block, sibling `.manifest.yaml`, or substrate-metadata schema? Research lap should answer.
3. **Live signal monitoring.** Watch new-capture cadence during Dark Code work. >2/week = re-stabilize signal.
4. **Fucina + luxlook downstream pulls** — operator-deferred. Do at session boundary when convenient, not during active development sessions (operator preference re: lost-state risk).

## Context Notes

* **Operator framing — "defect discovery rate exceeds defect closure rate":** when shipping 4+/session at substrate maturity, dogfood surfaces previously-invisible gaps faster than closure throughput. The cure is bounded: cap *capture* velocity (not closure velocity), drain to zero, then resume. Validated empirically in this turn — capture velocity hit zero on the last ship; backlog drained on schedule.
* **Theme rollover compression:** original Stabilization theme spec required a 14-day soak post-zero before evaluating next theme. Operator challenged this — "no reason to wait if backlog is cleared." Replaced with live throughput guard (>2 captures/week during Dark Code = re-stabilize). Decision-making validation: if substrate is genuinely stable, rollover-ready signal is BACKLOG-ZERO + EXIT-CRITERIA-MET, not BACKLOG-ZERO-AND-WAITED-FOR-A-SOAK.
* **Operator preference — full autonomous over hand-shipping.** Surfaced explicitly: "I don't want to hand ship. I want this to be an autonomous machine." Reconnection antidote shifted from "hand-ship a ticket per session" to "Dark Code as the next theme" — keep the operator connected to substrate via self-describing systems instead of forcing manual labor.
* **Dogfood-as-validation pattern, repeated:** BTS-237 fix proved on BTS-207's activate (the very next ship after merge). BTS-236 fix proved on every subsequent ship's PR title. This pattern was a stated thesis from prior memories — now 6+ consecutive sessions of validation.
* **Spec-time Subject derivation works.** BTS-236 ships H1 to `> Subject:` to PR title. Squash-merge subjects on main are now ≤72 chars + complete clauses. The earlier mid-sentence truncations (PRs #128, #131, #132, #133) are gone from PR #135 onward.
* **Process discipline held under pressure.** 9 ships with full TDD: spec, activate, plan, RED, GREEN, pr-cleanup, push, ship-finalize. No skipped steps even under context pressure. The lifecycle was the dominant time sink (vs the actual code change), but the discipline ensured every ship had drift-guards, evidence anchors, and live-API verification where applicable.

## Determinism Review

* operations_reviewed: \~145 (9 ships × \~16 ops each: spec write + Linear dispatch + retry, ticket transitions todo to in_progress to done, activate, plan write, bats RED + GREEN + cycle, full-suite verify, commit, push, pr-cleanup, push, ship dispatch)
* candidates_found: 0
* No candidates this session. The ship-finalize substrate (BTS-235 from prior session) made the post-PR phase deterministic. The pre-PR phase has irreducible Claude-judgment steps (spec composition, plan design, RED test design, GREEN implementation) — collapsing them into a single substrate verb would be either a thin wrapper (no leverage gain) or a delegation pattern that's already implicit (Claude orchestrates the steps autonomously). The actual leverage moves of this session — BTS-235 (post-pr substrate, prior session), BTS-237 (spec-activate race), BTS-236 (Subject metadata) — were already shipped as their own tickets and proven mid-flight.

## Evidence Gaps

No evidence gaps this session.

## Cross-Session Patterns

* **CONFIRMED RECURRING (sessions 4-9): dogfood-surfaces-substrate-correctness.** Session 9 added BTS-237 fix proven on BTS-207 + BTS-236 fix proven on every subsequent ship. 6th consecutive session of dogfood-as-validation. Memory `feedback_dogfood_probe_as_thesis_test` reinforced again.
* **NEW (session 9): backlog-drained-via-batched-stabilization.** First end-to-end demonstration of the stabilization framing — capture velocity hit zero, closure exhausted backlog, theme rolled over cleanly. Memory candidate (see Memory Candidates).
* **NEW (session 9): live-AC gates as same-session validation.** AC-5 (BTS-237) and AC-9 (BTS-236) explicitly designed as "next-ship-after-merge proves the fix" — both delivered. The "live-API gate" rule (`.claude/rules/tdd.md`) extended to "live-cycle gate" implicitly: any fix to the ship lifecycle gets validated by the next ship that uses it.
* **No legacy-refs surfaces.** `legacy-refs-scan` returned `[]`.
* **Audit-session findings (jq patterns in test fixtures): same false-positive set as prior sessions.** 5 patterns, all in new bats files (artifact-write-concurrent-edit.bats, session-info-jq-forks.bats, etc.). The audit detector flags `jq` as stochastic-shaped because tests use it for fixture construction; operationally these are deterministic test harnesses. Stable baseline; not actionable.

## Security Review

* **All 9 ships were substrate + skill-prose changes.** No new auth surfaces.
* BTS-209/208 hook helpers run with the existing CLAUDE_PROJECT_DIR scope; they write to `.ccanvil/state/` which is gitignored.
* BTS-237 added LINEAR_QUERY_OVERRIDE plumbing to cmd_artifact_write — TEST-only env var; production path unchanged.
* BTS-211 cmd_exec eval's resolved commands — same trust boundary as before (the resolver is operator-controlled config).
* BTS-183 sweep removed dead-code MCP branches; no surface change for live callers (zero of them).
* All 48 new bats tests use stubs (`LINEAR_QUERY_OVERRIDE`, `GH_OVERRIDE`, fixture JSON, PATH-shadow counted-jq) — no live API in CI.
* **Verdict: PASS.**

## Memory Candidates

* **NEW MEMORY:** `project_stabilization_drain_validated` — first end-to-end demonstration of the "cap capture velocity, drain backlog, theme-rollover" pattern. Anchored on session 9: 13 backlog to 0 in 9 ships, capture velocity hit zero on the final ship, theme rolled over to Dark Code. Validates the framing as operationally tractable, not just theoretical. **Save as project memory.**
* **NEW MEMORY:** `feedback_compress_artificial_soak_when_evidence_supports` — when the operator challenges a prescribed soak/wait window with a clear-eyed assessment of the underlying signal, compress the timeline. The 14-day Stabilization soak was overcautious; live-throughput monitoring is a better signal than calendar time. Anchored on the theme-rollover discussion late in session 9. **Save as feedback memory.**
* **REINFORCE:** `feedback_dogfood_probe_as_thesis_test` — BTS-237/236 fixes proved live on next ships. 6th consecutive session.
* **REINFORCE:** `feedback_finish_open_release_before_new_architectural_work` — operator's stabilization-first posture in this conversation explicitly held this rule.
* **No new external references** this session.