# Stasis: session-2026-05-13-bts-460-test-provider-indirection-ship

> Feature: session-2026-05-13-bts-460-test-provider-indirection-ship
> Kind: session
> Last updated: 1778694741
> Session: 51
> Boundary: 2026-05-13T10:30:00-07:00
> Session objective: Ship BTS-460 (theme-adjacent P2 from the converged Onboarding theme) — first concrete instance of the "hub describes behavior, node describes implementation" pattern.

## Accomplished

Session 51 — clean one-feature ship + triage drain. Theme-adjacent slice empirically validated; in-session dogfood under `/pr`'s real path closed the design-by-use loop.

* **3 Triage promotes to Backlog (start-of-session).** BTS-464 (`hub_source` plan-field rename, P3), BTS-465 (Determinism: template-mirror-sync, P3), BTS-470 (stacks\[0\] error wording, P3, sub of BTS-460). All non-blocking follow-up debt with clear next-ship shapes.
* **BTS-460 shipped end-to-end.** First concrete instance of the BTS-460 "hub describes behavior, node describes implementation" pattern. Substrate: new `cmd_test_suite_run` in `docs-check.sh` (reads `.test-provider` → `.stacks[0]` → default `bats`, exec's matching runner, fail-loud on unimplemented providers). `/pr` Step 2 migrated from hardcoded `bats-report.sh --parallel --progress` to dispatcher. `.ccanvil/guide/configuration.md` gains "Hub describes behavior" section with worked example + leak-site inventory (`tdd.md`, `stasis/SKILL.md`) as captured follow-ups. PR #183 merged on `8c31626`. BTS-460 → Done.
* **/review surfaced ONE BLOCKING bug in my own code:** `--slow-top` with missing N silently crashed under `set -euo pipefail` instead of exiting 2 with Usage. Fixed in-PR with explicit guard + new bats test; manifest declared `missing-slow-top-arg` failure-mode. Four CONCERNs addressed inline or captured (BTS-470 for stacks\[0\] error wording).
* **True dogfood under** `/pr`**'s real path:** the new dispatcher was the runner that gated /pr's own pre-merge test suite. 2280 / 2280 PASS via `docs-check.sh test-suite-run --project-dir . --parallel --progress`. End-to-end exercise of the substrate AND the migrated skill in one go.
* **/pr → /ship handoff frictionless (2nd consecutive session).** Same pattern as session 50: /pr left PR ready + lifecycle docs archived; /ship 183 ran title-assert (no-op) + merge + branch delete + land + auto-close in one substrate call. No manual intervention. BTS-235 substrate stable across consecutive ships.

## Current State

* **Branch:** `main` (clean, fast-forwarded through `8c31626`)
* **Tests:** 2280 / 2280 (parallel via the new dispatcher) — last invocation pre-merge.
* **Uncommitted changes:** none.
* **Build status:** clean. Manifest 195 / 195, drift 0.

## Blocked On

Nothing.

## Next Steps

**Operator's call — four live threads:**

1. **Triage drain.** 5 items in Triage that landed mid-session (not from this session's work): BTS-466 (Determinism: workspace guard heredoc false-positives), BTS-467 (Determinism: PR body update flow), BTS-468 (`/ccanvil-init` Step 10a: ask agent about provider activation, not just on TTY), BTS-471 (Determinism: idea capture project flag at capture time), BTS-472 (Determinism: stasis-routing transition orphaning). Trivial pass before next ship.
2. **Pivot to next theme — Personality Packs / Stacks tree.** Roadmap §Next Theme Direction sketches "Simplicity through Leverage" with personality packs (Musk, Bezos, Jobs). Alternative: BTS-453 stacks tree (start with BTS-454 — harden one-shot template guarantee). Either commits to a new theme.
3. **Theme-adjacent continuations.** P2 backlog still has BTS-337 (provider-heal legacy-data-scan), BTS-314 (onboarding repair: heal 3 drifted nodes), BTS-312 (test-runner indirection: pattern-anchor) — note BTS-312 is now partially superseded by BTS-460's ship.
4. **Roadmap freshness.** Roadmap still declares "Onboarding & Hub/Spoke Separation" as active 2026-05-06 — empirically converged across BTS-327 + BTS-460. Worth a 5-minute pass to mark theme `Shipped:` and re-anchor active theme before next ship.

## Context Notes

* **The "hub describes behavior, node describes implementation" pattern landed as a worked example, not a sweeping rewrite.** Per `feedback_lightweight_pattern_dogfoods_substrate_design`, the first ship introduced one dispatcher + migrated one skill + documented the pattern with a leak-site inventory. The remaining leak sites (`tdd.md`, `stasis/SKILL.md`) stay as captured follow-up until friction surfaces. Avoids the BUILD-vs-PATTERN over-commitment failure mode from past tickets.
* **The BTS-212 infinite-recursion trap was a surprise.** The dispatcher initially had no "no-args" check, so BTS-212 Shape A's `--project-dir <fixture>` invocation cascaded into `bats-report.sh hub/tests/` which ran the full suite including `test-suite-run.bats` which dispatched again, recursively. Caught structurally by the Shape A test timing out. Fix: require ≥1 forwarding arg in the bats path; no-args = exit 2 with Usage. The fix doubles as future-provider protection — applies to pytest/vitest dispatchers when they land. Recorded as manifest failure-mode `no-args` with explicit mitigation text.
* **The** `--slow-top` **BLOCKING bug from /review is a recurring shell-bashism.** Under `set -euo pipefail`, `var="${2:-}"; shift 2` succeeds at the assignment then fails the shift, exiting silently with code 1 and no stderr. Same shape as `feedback_set_e_kills_rc_capture` from earlier sessions. The lesson: under `set -euo pipefail`, ANY operation that mixes "ok-if-missing" semantics with strict-mode flow control needs an explicit guard before the optional consumption.
* **Argv whitelist vs** `--` **separator** — the dispatcher whitelists known [bats-report.sh](<http://bats-report.sh>) flags (`--parallel|--json|--timings|--progress|--slow-top N|--help|-h`) and uses `--` as the passthrough escape. Reviewer agreed: this is the right shape for a small, stable runner-flag surface. The `--` separator handles future [bats-report.sh](<http://bats-report.sh>) flags without forcing dispatcher edits; only "core" forward-flags need whitelist updates. Anti-pattern would have been: accept all `--*` blindly (typos become silent passthroughs that confuse at the runner layer).
* **In-session dogfood under** `/pr`**'s real path validated the migration more cheaply than fixtures could.** Step 8 of the plan (manual CLI invocation of the dispatcher on the hub itself) ran the test-suite-run.bats subset in 1082ms with `--json`. Step 2 of /pr ran the full suite via the dispatcher — same code path, real execution, fail-loud surface. Validates the operator-driven probe pattern from `feedback_dogfood_probe_as_thesis_test`.

## Determinism Review

operations_reviewed: 12
candidates_found: 0

No candidates this session. The session was end-to-end substrate-driven: /idea triage dispatches via http resolver, /spec→/activate→/plan→implementation→/review→/pr→/ship all went through their respective substrate primitives, the 5-file change set consisted of judgment-driven authoring (manifest content, doc prose, ACs) — no manual stitching of computable operations. The closest near-candidate was the `--slow-top` guard refactor, but that's a one-time substrate authoring decision, not a recurring stochastic op. /pr→/ship's frictionless behavior IS the substrate doing its job.

## Evidence Gaps

* BTS-466 — Determinism: workspace guard heredoc false-positives — missing-evidence-anchors
* BTS-461 — [guard-workspace.sh](<http://guard-workspace.sh>): refine slash-prefix detection to avoid false-positives on doc-body URL paths — missing-evidence-anchors

## Manifest Coverage

195 / 195 (allowlist), drift incidents: 0

## Cross-Session Patterns

Session 50 (1 ship, BTS-327, 8 triage promotes) → Session 51 (1 ship, BTS-460, 3 triage promotes). Pattern: theme-adjacent ramp slice every session, no theme-rotation overhead. BTS-465 from session 50's Determinism Review carries forward with `has_idea=true` (not orphaned).

Recurring patterns from prior stasis:

* `feedback_shape_gate_narrative_cascade` — did NOT fire. Discipline held two sessions running.
* **template-mirror-sync** carry-forward from session 50 — `count_carry_forward=0` confirms BTS-465 captured cleanly; the substrate verb still hasn't been built (still in Backlog at P3), but it's not orphaned.
* **batch-idea-create** carry-forward from session 49 — still NOT recurring. Captures this session were one-at-a-time http dispatches.

`legacy-refs-scan`: clean (0 matches). `audit-session`: 0 findings since `9b41a4b` — clean diff posture.

## Security Review

PASS. /review's security-audit step ran on the working tree pre-commit; 17 findings, ALL pre-existing on archived `docs/sessions/`, `docs/specs/bts-395-...`, `docs/specs/bts-72-...`, `hub/meta/operations.md`. ZERO findings on the 5 BTS-460-touched files. No secrets, tokens, PII, or credentials introduced.

## Memory Candidates

* `feedback_review_surfaces_real_blocker_in_own_code` — `/review`'s code-reviewer agent caught a BLOCKING bug (`--slow-top` missing-N silent crash under `set -euo pipefail`) that my own 19 bats tests didn't cover. The agent's flag-by-flag scrutiny of the new dispatcher was more thorough than my TDD slice ordering. Confirms `feedback_skip_review_on_trivial_diffs`'s carve-out: substrate-logic changes warrant /review even when the dev path looks complete.
* `feedback_dispatcher_no_args_trap_prevents_recursion` — when authoring a substrate dispatcher in `docs-check.sh` that forwards to a runner which can recurse into the project's own test surface (bats running the test-suite-run.bats fixture; future pytest/vitest dispatchers running their own discovery), the dispatcher MUST require ≥1 forwarding arg. No-args = exit 2 with Usage. BTS-212 Shape A's bare `--project-dir <fixture>` invocation is the canonical recursion-trigger shape; the new manifest field `failure-mode: no-args` captures the rule.
* `project_bts_460_shipped` — BTS-460 (test-provider indirection) shipped 2026-05-13 in PR #183 (`8c31626`). First concrete instance of the BTS-460 "hub describes behavior, node describes implementation" pattern. Sub-issue BTS-470 captured for stacks\[0\]-unknown-value error wording. Leak-site inventory documented in `.ccanvil/guide/configuration.md` as captured follow-up work (NOT shipped); future ramps surface naturally when pytest/vitest nodes pick up the pattern.

## Permissions Review Pending

(none — both promote-review.counts.total and check.danger are 0)