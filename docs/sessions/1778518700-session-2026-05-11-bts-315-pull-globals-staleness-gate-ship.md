# Stasis: session-2026-05-11-bts-315-pull-globals-staleness-gate-ship

> Feature: session-2026-05-11-bts-315-pull-globals-staleness-gate-ship
> Kind: session
> Last updated: 1778518700
> Session: 47
> Boundary: 2026-05-11T09:13:05-07:00
> Session objective: Ship BTS-315 (P1) — pull-globals staleness gate — opening the Onboarding & Hub/Spoke Separation theme

## Accomplished

Session 47 — BTS-315 specced, critic-reviewed, planned, implemented, reviewed, shipped end-to-end in one turn. First ship in the Onboarding & Hub/Spoke Separation theme (P1 anchor).

* **BTS-315 SHIPPED** (PR #180, merge `9b6e98d`). Added a non-mutating `--check` mode to `cmd_pull_globals` emitting a staleness envelope `{stale_count, stale[{name, hub_hash, local_hash}], missing_count, missing[{name}], up_to_date_count}`. Wired `/ccanvil-init` (via `global-commands/ccanvil-init.md`) with a Step 0 probe that emits a stderr warning naming up to 5 drifted files + the canonical recommendation `Run /ccanvil-pull-globals to refresh, then re-run /ccanvil-init.` Fires on every invocation regardless of project_mode; never blocks. 7 new substrate tests + 4 grep-assertion skill tests covering all 8 ACs. Full bats sweep 2227/2227, manifest 194/194 drift 0.
* **/spec --review (critic mode) caught a real coverage ambiguity** — AC-4's "before any user prompt" was undefined relative to the already-initialized interactive branch (which itself prompts the user). Fixed pre-activate by rewriting AC-4 to specify "first action of Step 1, before the project-mode detection AND before the already-initialized interactive options block, regardless of which branch follows." Also added AC-8 for the degenerate empty-hub case per critic's secondary observation. Spec went from 7 ACs to 8.
* **Code-reviewer caught a real read-only-contract violation.** `mkdir -p "$dst_dir"` ran unconditionally before the `if $check` branch, meaning `--check` would create `~/.claude/commands/` as a side effect when it didn't exist. Fixed by moving `mkdir -p` into the mutate path only, AND tightening the AC-1 test to assert `[ ! -d "$FAKE_HOME/.claude/commands" ]` (closes the test gap that masked the directory side-effect). The manifest's `contract: --check-is-read-only` is now actually verified by the test.
* **Plan resolved 3 architectural open questions at plan-time** (not spec-time, per session 42-43's emerging pattern). Option A single function with `if $check` branch (vs extracted helper); full hashes in the envelope (vs names-only); Step 0 IS the first action of Bootstrap and preflight (vs separate pre-step). All three justified by leverage of existing substrate.
* **Plan-spec hash drift trapped, then recovered cleanly.** Pre-`/pr` lifecycle gate flagged `state: blocked` with two blockers: `stasis.md missing` AND `spec content changed since plan was written` (because the spec was edited post-plan-write to fix the `hub/tests/ccanvil-sync.bats` → `hub/tests/pull-globals.bats` row in Affected Files). Re-dispatched the plan with current spec hash `a25d83dc` (was `637fd2d7`); state cleared to `plan-written`, both blockers gone. Confirms the lifecycle gate is doing its job — caught real drift before it shipped.

## Current State

* **Branch:** `main` (clean, fast-forward through `9b6e98d`).
* **Tests:** 2227 / 2227 (full parallel sweep GREEN; the previously-flaky `module-manifest-query-helpers.bats:46` test even passed this run, suggesting the race window may be narrower than feared — keep observing across sessions but de-prioritize a deterministic fix).
* **Uncommitted changes:** none.
* **Build status:** clean. PR #180 merged, branch deleted, BTS-315 auto-closed to Done. Manifest 194/194 drift 0.

## Blocked On

Nothing.

## Next Steps

The Onboarding & Hub/Spoke Separation cluster has 9 more tickets in priority order. Per roadmap:

1. **BTS-316 (P2 umbrella)** — Modular provider connectivity, forklift-heal flow. Strategic anchor. Subsumes 313 + 314. Major-effort spec session.
2. **BTS-313 (P2)** — Linear provider activation: deterministic flow during `/ccanvil-init`. Implementation slice under 316.
3. **BTS-314 (P2)** — Onboarding repair: Linear-config audit substrate + heal pass for 3 drifted nodes (unifi done; inbox + microsoft365 remain). Now smaller in scope because BTS-315 closes the staleness-detection half of the same problem (config drift was one symptom, skill drift was another; both now have detection substrate).
4. **BTS-320 / BTS-321 (P2)** — provider-heal Phase 2 (substrate-drift gate) + Phase 3 (LINEAR_API_KEY preflight). Compose with BTS-319 (already shipped session 25).
5. **BTS-324 (P2)** — `routing.ticket` non-canonical key rename → `routing.idea` (concrete inbox-toolbox heal). Smallest action; cache-warm cadence-eligible.
6. **BTS-312 (P2)** — Test-runner indirection: generic test-suite verb. Pattern-anchor for hub/spoke separation.
7. **BTS-322 (P3)** — `pull-auto-with-new`: fold accept-new per-file loop.
8. **BTS-323 (P3)** — `ccanvil-sync.sh` self-update mid-pull-auto crash hardening.
9. **BTS-204 — SSOT-Linear** (Triage, major effort). Still ambient strategic work; cluster-aligned because Linear-routing matters for onboarding.

Canonical opener for session 48: pick BTS-324 (smallest cache-warm fix to keep cadence) OR BTS-316 (dedicated spec session for the umbrella). If session-48 has capacity for major-effort spec work, prefer BTS-316; otherwise BTS-324.

## Context Notes

* **One-turn spec-to-ship cadence continues to hold at substrate maturity** — three consecutive sessions (BTS-419, BTS-418, BTS-315) shipped in one turn each. Shape: spec → critic → activate → plan → TDD → review → /pr → /ship. BTS-315 reused the existing `pull-globals.bats` fixture pattern (FAKE_HOME + temp hub) AND the existing `ccanvil-init-skill.bats` grep-assertion pattern. The leverage from prior substrate keeps making one-turn cadence feasible.
* **Critic-mode is now \~3-for-3 on non-trivial specs catching real ambiguity** — session 42 (BTS-419 manifest scope), session 43 (BTS-418 maximal-config), session 47 (BTS-315 "before any user prompt"). Adopt as standard pre-activate gate for tickets with ≥3 ACs or "Implementation Notes options." Cost is one agent invocation + one spec edit; benefit is zero mid-impl interpretation drift.
* **Lifecycle gate caught spec-edit-after-plan-write drift in real time.** This is BTS-20's intended behavior firing exactly as designed. The gate's `spec content changed since plan was written` blocker stopped a /pr that would have shipped a stale plan. Re-dispatching the plan with the new spec hash cleared the blocker; the entire round-trip took \~30 seconds. Empirical signal: the spec-hash check pays for itself even on a routine 1-line edit. Worth more dogfooding.
* **The fix for the code-reviewer's WARN was 2 LOC + 1 test assertion** — small mechanical fix but a real correctness improvement (the manifest's `contract: --check-is-read-only` now matches behavior). Reviewer's "WARN (1)" + "WARN (2)" were coupled (test gap masking substrate bug); fixing the substrate AND tightening the test in the same diff is the right move.
* **Stale-cache override pattern (**`ALLOW_CONCURRENT_EDIT_OVERRIDE=1`) used twice this session — once on the spec re-dispatch after the AC-4 fix, once on the plan re-dispatch after the spec-hash refresh. Both legitimate overrides (no concurrent editor; my own prior dispatch staled the cache). Worth noting that within a single autonomous session, this is common; the override is a tax we pay on multi-edit specs, NOT a substrate bug.
* **PR title was already correct on first push** — `feat(bts-315-pull-globals-staleness-gate): pull-globals staleness gate`, no `assert-pr-title` force-update needed. The `> Subject:` metadata (stamped at spec creation) flowed through cleanly into the PR derivation. BTS-236 substrate continues to hold.

## Determinism Review

operations_reviewed: 18
candidates_found: 0

No candidates this session.

Both stochastic-replacement opportunities surfaced this session were caught and converted DURING the session, not deferred:

1. `/spec --review` critic-mode replaced "Claude eyeballs the spec for coverage gaps" — deterministic agent-with-rules invocation. Already substrate (BTS-266); just being used correctly.
2. Code-reviewer's WARN-as-blocking was real, not noise — the substrate test was insufficient, fixed in the same diff. No new stochastic-op pattern fell out of impl.

The lifecycle-state blocker (`spec content changed since plan was written`) IS a deterministic gate working as designed; no candidate.

## Evidence Gaps

No evidence gaps this session.

## Manifest Coverage

194 / 194 (allowlist), drift incidents: 0. Status: ok. Unchanged from session 43; the BTS-315 substrate change added two manifest entries (`# input: --check`, `# caller: global-commands/ccanvil-init.md`) inline, no drift introduced.

## Cross-Session Patterns

* **Recurring (positive, now 4+ sessions): one-turn spec-to-ship at substrate maturity.** BTS-419 → BTS-418 → BTS-315. Each ship reused the prior session's test patterns and substrate primitives. Cadence holds when the ticket is structurally adjacent to a recent ship OR sits cleanly on top of existing substrate. BTS-315 wasn't structurally adjacent to BTS-418 but was cleanly on top of `cmd_pull_globals` + existing bats fixtures.
* **Recurring (positive, \~3-for-3): /spec --review critic-mode catches real coverage ambiguity.** Three consecutive non-trivial specs (BTS-419, BTS-418, BTS-315). Validate-spec is the structural floor; critic-mode is the semantic ceiling. Adopt by default for ≥3 ACs.
* **Recurring (positive): code-reviewer catches real WARN-level findings even when validate-spec + manifest are clean.** Session 42 BTS-419 (manifest exit-path gap), session 43 BTS-418 (forward-looking edge cases), session 47 BTS-315 (read-only-contract violation + test gap). Different shape each time but consistent value pattern.
* **NEW (this session): lifecycle-state gate catches plan-spec hash drift in real time.** The `spec content changed since plan was written` blocker fired on a legitimate mid-flow spec edit (Affected Files row correction). The gate's behavior is exactly right — preferring strict drift detection over silent stale-plan ship.
* **NEW (this session):** `> Subject:` metadata pipeline holds end-to-end without intervention. BTS-236's substrate continues to make PR titles deterministic — no `assert-pr-title` force-update fired.
* **No legacy-refs drift** (legacy-refs-scan: 0 matches).
* **No audit-session findings** (`audit-session --since 3879bda`: empty patterns array, 0 findings).

## Security Review

PASS — no NEW secret/PII patterns introduced this session. Diff content: bash substrate + bats fixtures + skill prose + spec/plan markdown. New helpers parse JSON envelopes, compute file hashes (existing `file_hash` helper), and run `mkdir`/`cp` only on the mutate path. No env-var reads beyond existing `$HOME`. The 17 baseline findings (`docs/sessions/`, `hub/meta/operations.md`) are pre-existing and unchanged.

## Memory Candidates

* **Feedback (validated):** `feedback_lifecycle_gate_catches_real_plan_spec_drift` — `lifecycle-state` blocker `spec content changed since plan was written` legitimately fires on mid-flow spec edits (e.g., Affected Files row corrections). Recovery is cheap: re-dispatch the plan with the current spec hash. NOT a substrate bug — the gate working as designed. Within a single autonomous session, plan-spec-hash refresh is part of /pr prep when the spec was edited post-plan-write. Session 47 anchor.
* **Feedback (validated):** `feedback_code_reviewer_warn_couples_with_test_gap` — when code-reviewer flags a substrate WARN and a matching test-gap WARN in the same review, fix BOTH in the same diff. The test gap is what allowed the substrate bug to land in the first place; fixing only the substrate leaves the test silently passing on the next regression. Session 47 anchor: BTS-315 `mkdir -p` side-effect.
* **Feedback (validated):** `feedback_critic_mode_three_consecutive_real_finds` — `/spec --review` critic-mode has now caught real coverage ambiguity on three consecutive non-trivial specs (BTS-419, BTS-418, BTS-315). Adopt as standard pre-activate gate for ≥3 ACs or "Implementation Notes options" specs — track-record now solid enough to recommend by default, not just on critic discretion. Refines `feedback_critic_mode_catches_coverage_ambiguity`.
* **Project:** `project_onboarding_theme_opened` — Onboarding & Hub/Spoke Separation theme officially opened with BTS-315 SHIPPED (session 47, 2026-05-11). 9 tickets remain in the cluster. Next canonical opener is BTS-324 (smallest, cache-warm-eligible) OR BTS-316 (major-effort umbrella spec). Theme exit criteria: new-node onboarding produces correct + complete config in one operator command, verified on a fresh node.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->