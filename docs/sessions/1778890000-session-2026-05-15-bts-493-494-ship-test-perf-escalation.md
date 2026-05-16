# Stasis: session-2026-05-15-bts-493-494-ship-test-perf-escalation

> Feature: session-2026-05-15-bts-493-494-ship-test-perf-escalation
> Kind: session
> Last updated: 1778890000
> Session: 54
> Boundary: 2026-05-15T11:14:04-07:00
> Session objective: Diagnose + ship the unifi-toolbox-captured BTS-493 pull-plan misclassification bug; extend the fix across the remaining sync consumers (BTS-494); operator escalated test-suite wall-time as P0 mid-session → captured as P1 research ticket BTS-497.

## Accomplished

Session 54 — two ships + three research/follow-up captures + triage drain. Two production-impact bugs shipped end-to-end via the canonical lifecycle, validating cross-node bug-flow (downstream agent files an evidence-rich ticket; hub picks it up and ships through spec→activate→plan→TDD→review→pr→ship). Mid-session operator escalation on test-suite velocity captured as P1 with full diagnostic data, not deferred.

* **Triage drain at session start (5 items).** BTS-466/471/472 promoted to Backlog P3 (all "Determinism:" carry-forwards from session 51). BTS-467 merged into BTS-397 (PR body refresh — same surface). BTS-468 merged into BTS-313 (onboarding provider-activation — theme parent absorbs it). Auto-mode classifier blocked the merge dispatches initially; operator authorized both via AskUserQuestion. Mid-flow a new Triage item (BTS-493) appeared captured by an agent at unifi-toolbox — left in Triage for investigation, became the headline ship of the session.
* **BTS-493 shipped (PR #186,** `8fa19dd`**).** Captured by unifi-toolbox agent with full evidence anchors (Command/Output/Exit/Reproduce) during routine `/ccanvil-pull`. `cmd_pull_plan`/`cmd_pull_auto`/`cmd_pull_apply` misclassified `INIT_GITHUB_TEMPLATES`-mapped lockfile entries as `removed` because the lockfile-key (dest path) ≠ hub-side path (template path) for the 5 GitHub config files. Shipped new bash-3.2-safe helper `_resolve_hub_relpath_for_lockfile_key` + 3 call-site rewrites + 15 bats tests. /review APPROVE with 2 CONCERN captured as follow-up. Time-to-ship from capture to merge: \~1h40m.
* **BTS-494 shipped (PR #187,** `3e71d50`**).** Phase 2 of the path-resolution story — extended the BTS-493 helper to `cmd_diff` (4 call sites) + `cmd_push_candidates` (1 call site). Same substrate, same pattern, 9 bats tests. /review caught one BLOCKING (helper's `caller:` list didn't include the 2 new consumers — bidirectional drift-guard gap; fixed in-PR; captured root cause as BTS-495) + 1 CONCERN (AC-4 clean-status path coverage; added sub-test). Time-to-ship from capture to merge: \~1h. Substrate reuse made it materially faster than BTS-493.
* **Three research/follow-up captures.** **BTS-495 (P3 Backlog target):** `Determinism: helper-caller-list-auto-update` — substrate-improvement candidate (bidirectional caller-graph validation in `module-manifest.sh validate` would have caught the BTS-494 BLOCKING structurally rather than relying on the reviewer agent). **BTS-496 (Triage):** `Research: Layman summaries on every captured artifact for operator clarity` — operator-explicit request to add jargon-free human-readable sections to every artifact (tickets, specs, plans, stasis, substrate docs); explicitly scoped as needs-research before spec. **BTS-497 (P1 Triage):** `Research: Persistent per-test performance metrics for retrospective analysis` — operator escalated as "killing us"; full diagnostic data + 8 open research questions in body.
* **Roadmap freshness pending.** "Onboarding & Hub/Spoke Separation" theme is empirically converged across BTS-327/460/482/488/493/494. Worth marking Shipped next session and re-anchoring active theme. Not done this session — left for operator's next pass.

## Current State

* **Branch:** `main` (clean, fast-forwarded through `3e71d50`)
* **Tests:** 2338 / 2338 PASS (parallel, jobs=12, wall_s=401) — last invocation 2026-05-15T23:22Z pre-merge of BTS-494. NOT re-run for this stasis at operator's explicit direction (see BTS-497 below).
* **Uncommitted changes:** none.
* **Build status:** clean. Manifest 197/197, drift 0 (verified post-BTS-494).
* **Backlog:** 41 (+3 from session-52 baseline 38) — BTS-493 → Done, BTS-494 → Done, BTS-466/471/472 promoted, BTS-495 captured (priority TBD).
* **Triage:** 5 — includes new BTS-496, BTS-497 from this session + 3 carry-forwards from session 52 (BTS-486, 487, 491 or 492).

## Blocked On

Nothing technically. **Operator-stated**: test-suite wall time (\~6.7 min per full run; 5 runs/ship = 30 min/ship) is consuming velocity. BTS-497 captures the research lap needed.

## Next Steps

**Top priority (operator-escalated):**

1. **BTS-497 — Persistent per-test performance metrics (P1).** Operator framing verbatim: "We need to get test-level performance metrics that are collected every single time tests run, at all times, logged somewhere meaningful." Designated as needs-research; dedicated session. The body contains 8 open research questions covering storage shape, retention, capture overhead, retrospective tooling, regression detection thresholds, slow-test SLO, root-cause classes, and cross-system impact. Existing partial work: BTS-118 (bats-report), BTS-137 (--timings flag, ephemeral), BTS-282 (bats-profile, fork-pressure-focused), BTS-283 (Backlog: soak-tracking remote agent, blocked on per-test data persistence). The dedicated session should: (a) run a `--timings` capture now to surface today's slow-top distribution, (b) bucket slow tests by class (fixture setup vs. dispatcher call cost vs. sequential assertions), (c) define the storage + retention shape, (d) /spec from there.

**Then operator's call:**

2. **BTS-496 — Layman summaries research (Triage, no priority yet).** Dedicated research session to define audience, generation model, enforcement, structure. Companion to BTS-497 — both surface from the same "operator-comprehension friction" axis.
3. **BTS-489 (P2) — init-time lockfile registration gap.** The root cause BTS-488/493/494 all worked around. Closing this means fresh-init nodes get template-mapped entries registered without needing a subsequent heal.
4. **BTS-483 (P2) — false-alert hardening + ci-pull meta-loop (Phase B).** Strategic ask from the CI fire-drill session that originated BTS-488. Now BTS-493 + BTS-494 close the distribution side; Phase B addresses the consumption side.
5. **BTS-495 (P3 target) — bidirectional caller-graph validation.** Substrate-improvement that would have caught the BTS-494 BLOCKING structurally. Small implementation, high recurrence value.
6. **Roadmap freshness pass.** Mark "Onboarding & Hub/Spoke Separation" Shipped; re-anchor active theme (Dark Code is still nominal, but the BTS-493/494 work was more "fleet-distribution-correctness" than Dark Code).

## Context Notes

* **The BTS-493 → BTS-494 cadence was unusually fast (1h40m + 1h hands-on) because the substrate from BTS-493 made BTS-494 essentially a copy-paste extension.** Same helper, 5 call-site rewrites instead of 3, identical bats fixture pattern. Validates the "ship substrate primitive → exercise on adjacent surfaces same-session" pattern from `feedback_same_session_dogfood_validates_thesis`. The downstream agent at unifi-toolbox filed BTS-493 with full evidence anchors, hub picked it up and shipped, then immediately surfaced + shipped the adjacent fix BTS-494 → that's the cross-fleet self-healing thesis demonstrated in one session.
* **BTS-497 is the most important capture of the session.** Test-suite wall time stabilized at \~400s for parallel-12-job runs across 2189 → 2338 tests (linear \~200ms per added test). At 5 full-suite runs per ship (recall + pre-merge + pr-cleanup-pre-merge × 2 + activations + ...), that's \~30 min/ship inside bats. Operator-stated as "killing us." Existing tooling captures aggregate `wall_ms` per run in `.ccanvil/state/bats-runs.jsonl` (1734 historical rows) but NOT per-test timings — those are emitted to stdout by `--timings --slow-top N` ephemerally and lost. The research lap defines the storage + retention shape. Don't start implementation until research lands.
* **Auto-mode classifier blocked merge dispatches mid-triage.** When I dispatched `ticket.transition BTS-467 duplicate --duplicate-of BTS-397` and similar for BTS-468, the auto-classifier flagged it as "modifies an external Linear ticket the agent didn't create this session" — required AskUserQuestion authorization before the merges landed. The promote/dismiss transitions weren't blocked (presumably because state-transition without target-id-arg is less consequential). Pattern: anything that mentions another ticket as a target needs explicit operator authorization in auto-mode. Worth knowing for future triage drains.
* **The /review BLOCKING on BTS-494 (helper caller-list stale) was the highest-value finding of the session.** `module-manifest.sh validate` returned drift=0 even though the helper's manifest claimed 3 callers when the diff added 2 more. The substrate enforces forward direction (declared caller: must grep-resolve) but NOT reverse (every grep-able caller must be declared). The diff-vs-manifest gate (BTS-268) also missed it. Captured root cause as BTS-495 — bidirectional caller-graph validation would have caught it structurally. The code-reviewer agent essentially IS the missing substrate primitive today.
* `scan_hub_files` **empty-array set-u trip is a latent substrate bug.** When the hub fixture in BTS-493 bats tests had no `TRACKED_PATTERNS` matches (sparse tmpdir), `scan_hub_files` emitted `files[@]: unbound variable` to stderr. Workaround: every bats test uses `run --separate-stderr` to isolate stdout for JSON parsing. Pre-existing minor bug; captured implicitly in the test fixture pattern, not as a separate ticket. Worth a follow-up if it recurs.

## Determinism Review

operations_reviewed: 23
candidates_found: 1

* **bidirectional-caller-graph-validation**: Claude manually maintained `caller:` lists on @manifest blocks when adding new call sites. In BTS-494, the helper's caller list was NOT updated when 2 new consumers were added — caught by the code-reviewer agent as BLOCKING, not by `module-manifest.sh validate`. Should be: a substrate verb that derives the caller graph from grep (or the existing manifest index BTS-281 built) and validates the declared list matches. Impact: high — every new caller-of-an-allowlisted-helper case currently relies on the reviewer agent OR the author noticing. Dual-capture: already captured as BTS-495 in Backlog earlier this session.

## Evidence Gaps

No evidence gaps this session.

## Manifest Coverage

197 / 197 (allowlist), drift incidents: 0

## Cross-Session Patterns

Session 52 (2 ships: BTS-482+488 + fleet heal) → Session 53 (gap — recall+stasis only; no ships) → Session 54 (this: 2 ships BTS-493+494 + 3 captures + escalation). Pattern shift: **cross-node bug-flow demonstrated end-to-end** — downstream agent filed an evidence-rich ticket against the hub, hub shipped both the immediate fix and the adjacent extension in one session. Validates the agentic-agency-first thesis from `feedback_agentic_agency_first`.

Recurring patterns from prior stasis:

* `feedback_review_surfaces_real_blocker_in_own_code` **recurred.** Session 51 BLOCKING was the `--slow-top` strict-mode-bashism; Session 52 BLOCKINGs were the `ready_for_review` and orphan-retry gaps; Session 54 BLOCKING was the helper caller-list stale. Three consecutive sessions where the reviewer agent caught real bugs the author missed. Argument for: keep `/review` mandatory on substrate-logic diffs (per `feedback_skip_review_on_trivial_diffs` carve-out, only skip on pure-prose).
* **Same-session substrate dogfood.** Session 50 (BTS-235), Session 51 (BTS-460), Session 52 (BTS-488), Session 54 (BTS-493→494 chain). Each shipped a substrate primitive and exercised it within the same session. The cadence holds.
* **No recurring determinism candidates.** Session 51 had zero candidates. Session 52 had one (`fleet-post-heal-push`, captured to pending log when Linear was down, sync state unknown — needs follow-up `/idea sync` next session to confirm). Session 54 has one (`bidirectional-caller-graph-validation`, captured as BTS-495). No repeated candidates yet — substrate is catching specific gaps as they surface.

`legacy-refs-scan`: clean (`[]`). `audit-session`: deferred (test runtime was operator-deprioritized; session-52 baseline was 34 findings, mostly fleet-iteration `git -C` patterns).

## Security Review

PASS. /review's security-audit step ran on both BTS-493 and BTS-494 working trees pre-commit; 17 findings total, ALL pre-existing in archived `docs/sessions/`, `docs/specs/bts-72-...`, `docs/specs/bts-395-...`, `hub/meta/operations.md`. ZERO findings on the 5 BTS-493/494-touched files (`.ccanvil/scripts/ccanvil-sync.sh`, `.ccanvil/manifest-allowlist.txt`, `hub/tests/pull-plan-init-templates-mapping.bats`, `hub/tests/diff-push-init-templates-mapping.bats`). No secrets, tokens, PII, or credentials introduced.

## Memory Candidates

* `feedback_test_velocity_p1_escalation` — Operator explicitly escalated test-suite wall time as P0/P1 mid-session: "killing us." Triggered immediate capture (BTS-497 at P1) + dedicated stasis prominence. Pattern: when operator stops the active flow with a velocity concern, the right move is (a) kill any in-flight wasteful compute, (b) capture the issue with full diagnostic context as research-shape (not fix-shape), (c) prioritize at top of Next Steps. Don't try to fix it in the same session unless the fix is genuinely trivial.
* `feedback_layman_artifacts_protocol_required` — Operator-stated: artifacts (tickets, specs, plans, stasis) are too domain-dense; operator can't read them without re-deriving context. This is degrading the approval gate (regularly approving on trust rather than comprehension). Future substrate work should treat layman-readability as a structural requirement, not an optional nicety. Captured as BTS-496.
* `feedback_cross_node_bug_flow_validated` — A downstream agent at unifi-toolbox captured BTS-493 with full evidence anchors (Command/Output/Exit/Reproduce) and the hub picked it up and shipped within hours. This validates the cross-fleet self-healing thesis end-to-end. The hub doesn't need to monitor every node; nodes file evidence-rich tickets when they hit substrate bugs. Confirms `feedback_agentic_agency_first` at fleet scale.
* `reference_bats_runs_jsonl_schema` — `.ccanvil/state/bats-runs.jsonl` records per-run aggregate `{epoch, wall_ms, ok, not_ok, total, jobs, cpus, raw_exit, parallel, failures}`. 1734 historical rows. NO per-test timings persisted (only `wall_ms` aggregate). `bats-report.sh --timings --slow-top N` emits per-test timings to stdout but ephemerally. BTS-283 in backlog is blocked on per-test data; BTS-497 unblocks it.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->