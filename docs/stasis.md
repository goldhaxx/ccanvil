# Stasis

> Feature: session-2026-04-24-bts-128-ship
> Kind: session
> Last updated: 1776996739
> Session objective: Triage the Linear inbox (per prior stasis Next Step #1), then ship BTS-128 (`ticket.transition` wrapper) end-to-end — the high-leverage determinism candidate the prior stasis flagged as recurring. Dogfood by self-closing BTS-128 with the wrapper it just shipped.

## Accomplished

- **Shipped PR #47 (`fc5aaaf`)** — `bts-128-ticket-transition`. 8 commits on branch; 6 TDD phases (12 steps) plus 1 code-review-fix commit plus 1 lifecycle cleanup commit. Full suite **850/850 bats green** (+14 from 836 baseline in `hub/tests/ticket-transition.bats`). Clean squash-merge + FF `land`. **Zero regressions** — one test in `idea-triage-native.bats` required an update to match the refactored `/idea` skill vocabulary (legitimate test update for the dispatch change).
- **BTS-128 closed via the wrapper it just shipped** — first real-world invocation of `operations.sh resolve ticket.transition BTS-128 done --project-dir .` + MCP `save_issue` dispatch. No manual UUID paste. Dogfood moment: the determinism candidate the prior stasis flagged closed itself via its own fix. Linear auto-attached PR #47 to BTS-128 via the branch-substring match (`claude/feat/bts-128-ticket-transition`).
- **Linear Triage inbox fully drained (11 → 0)** — 6 original Triage items promoted to Backlog with priorities (BTS-128 High, BTS-122/123/127/129 Medium, BTS-125 Low). Plus 5 legacy-local captures migrated to Linear as BTS-131 through BTS-135 (all Medium). Zach's question mid-flow — "what's the purpose of keeping the local copy? can't we just delete them if they make it to linear?" — refined the migration plan from "migrate + mark local as duplicate" to "migrate + delete" (clean architecture; the marker vocabulary only makes sense pointing at Linear IDs, not at local archeology).
- **New `ticket.transition <id> <role>` verb** in `operations.sh` — resolves role → state UUID via existing `linear_state_id` helper; supports all 6 roles (`triage | backlog | icebox | canceled | duplicate | done`); emits a save_issue payload with BOTH `id` and `stateId` pre-populated, so caller dispatches a single MCP call. Error paths: missing id/role produce distinct actionable errors; unknown role rejected with vocabulary listing; unconfigured role fails loud with config-file pointer; local provider explicitly unsupported.
- **`done` role added** to `state_ids` with the Blocktech "Done" UUID `bc6aa160-258d-4eae-b3b5-a2575732a188`. AC-4 acknowledged as smoke-test-verified-only in spec (bats cannot cover because `.claude/ccanvil.local.json` is gitignored). Downstream nodes get AC-5 loud error ("role 'done' not configured") until they migrate — no silent failures.
- **Argument parser extended to `OP_ARG2`** — minimal, backward-compat change to `.ccanvil/scripts/operations.sh` loop so two-arg ops (`ticket.transition <id> <role>`) work without quoting tricks. Regression test for single-arg ops (`backlog.get BTS-42`) locks in the invariant.
- **`/idea` skill refactored** — triage dispatch table now routes through `ticket.transition <id> <role>` instead of four separate `idea.{promote,defer,dismiss,merge}` resolvers. Old resolvers preserved for backward compat but are now dead code from the skill's perspective (NIT-2 for later cleanup).
- **Routing fallback extended** — `ticket.*` group falls back to `idea` provider routing (same pattern as BTS-130's `work.*` fallback). Linear-configured nodes need no new `routing.ticket` entry.
- **Code review caught 3 WARN items, all fixed pre-merge** (commit `9e32cea`): AC-1 test weakness (passed on exit-1 silently — tightened to assert `status -eq 0`), AC-4 spec language (added smoke-test/gitignore acknowledgment), stale `usage()` (extended with `idea.*`, `work.resolve`, `ticket.transition`). 3 NITs deferred to future follow-ups.
- **BTS-120 session-stasis trap DID NOT RECUR** — first session in 5 consecutive where `activate` did NOT require the `git rm docs/stasis.md` workaround. The BTS-130 structural fix (Kind: session discriminator) worked in production. Symmetric payoff.

## Current State

- **Branch:** `main` at `fc5aaaf`, synced with origin.
- **Tests:** 850/850 bats green at PR HEAD; post-merge on main: not re-run (squash was FF-equivalent).
- **Uncommitted changes:** none (working tree clean post-`land`).
- **Build status:** clean.
- **Context budget:** 5188 / 8000 tokens = 64.8% (HEALTHY — unchanged from prior, no new context-weight files added to session-pinned set).
- **Permissions audit:** 20 DANGER + 166 UNREVIEWED (unchanged from prior session — no new permission surface).
- **Specs archive:** 44 complete (was 43); no active/ready/in-progress specs.
- **Linear state:** 24 ideas total; 0 in Triage (all drained); 14 in Backlog (BTS-122/123/125/127/128(done)/129/131-135 + prior items). BTS-128 closed. PR #47 attached.

## Blocked On

- Nothing.

## Next Steps

1. **Ship BTS-119** (auto-close Linear on merge) — NOW directly unblocked by BTS-128's `done` role + `ticket.transition` primitive. The branch substring convention is already live (BTS-130). Missing piece: a PR-merge hook that extracts the ticket id from the branch name and calls `ticket.transition <id> done`. Small ship (~1 hr), delivers high-frequency ongoing automation.
2. **Ship BTS-122** (pre-activate guard audit) — comprehensive review + hardening of pre-flight checks. 10 enumerated gaps in the ticket description; good scope for a focused session.
3. **Ship BTS-127 + BTS-118** (bats assertion-leak family) — bundle one ship. The preventative "combined `jq -e` with `and`" pattern was used in this session's new tests; codifying it for the existing suite is the remaining work.
4. **Ship BTS-123** (pending-log fallback integrity) — correctness bug in the MCP-down replay path. Sibling to BTS-129 (ticket.find-by-title) which BTS-123 needs for idempotent replay.
5. **Ship BTS-129** (ticket.find-by-title wrapper) — sibling of BTS-128 in the same deterministic-wrapper family. Needed as a primitive for BTS-123.
6. **Ship BTS-131-135** (ccanvil tooling correctness bundle) — 5 small determinism/correctness improvements captured as local archeology, now in Backlog. Candidates for bundling: BTS-131 (bats double-run → one-shot reporter) unlocks a session-wide efficiency win; BTS-134/135 (script JSON contracts) are sub-30-min each.
7. **Ship BTS-125** (Linear save_issue markdown truncation codification) — P4, workaround exists. Nice-to-have; ship when a larger-scope session wants a small finisher.
8. **Pick from longer-horizon Backlog**: BTS-113 (stale recommend after stasis+compact+recall).

## Context Notes

- **Triage flow was cleaner than prior sessions because inbox was small + recent.** 6 Linear Triage items + 5 local-legacy = 11 total. All captured in the last 48 hours with tight scope. Decision table was "promote + priority" across the board — no defers, no dismisses, no merges. This is a signal that the session-before-triage cadence is about right; inbox didn't accumulate drift.
- **Migration pattern: JSONL filter by UID + rewrite + verify + delete backup.** Reusable for any future `.ccanvil/ideas.log` → Linear migration. Used `jq -c 'select(.uid | IN(...) | not)' > tmp && mv tmp orig`. Backup saved as `.bak`, deleted after verifying Linear + local counts matched. Pattern could become a `docs-check.sh idea-migrate-to-linear` subcommand IF it recurs on downstream nodes (fucina/luxlook) — noted as a conditional candidate, not yet worth shipping.
- **Mid-TDD spec edit required a plan-hash rebase.** Edited AC-4 in `docs/spec.md` for the WARN-2 fix; validator immediately flagged `stale-plan` because the plan's `> Spec hash:` was now stale. Fixed by updating `plan.md` hash in place. Pattern worth internalizing: any spec edit after `/plan` needs a plan-hash rebase to keep the lifecycle aligned.
- **Parser RED-first trap** — Step 1's RED test was accidentally too loose (a command-invocation with `backlog` as a THIRD positional tripped the old parser's "Unknown option" catch-all BEFORE `is_valid_operation` ran). Caught in-flow, tightened to a single-arg invocation that isolates the op-validation check. Lesson: "RED" must actually fail for the RIGHT REASON, not just fail. Fixed test → reconfirmed RED → then GREEN. WARN-1 in review later tightened it further to assert `status -eq 0` explicitly.
- **Combined `jq -e` assertions used preventatively** in new tests — BTS-127 is the ticket for fixing the silent-leak pattern across the whole suite. New tests in `ticket-transition.bats` used `jq -e '.a == x and .b == y and ...'` to keep assertion semantics strict. Pattern is cheap and should be the default going forward.
- **The BTS-130 fix worked in production** — activate on fresh main didn't need the `git rm docs/stasis.md` workaround. This is the first session in 5 consecutive where the BTS-120 trap didn't fire. Structural fix confirmed.
- **Dogfood timing was deliberate** — BTS-128 closed BY its own wrapper AFTER the squash merge, not before. The `done` UUID in `.claude/ccanvil.local.json` was the last piece of the happy path; smoke-testing it end-to-end (real config, real MCP call, real state transition) as the final act is exactly the invariant BTS-128 promises to hold forever after. AC-4 had no bats coverage by design — this live invocation is the verification.

## Determinism Review

- **operations_reviewed:** 22
- **candidates_found:** 1 new conditional + 1 resolved recurring
- **RESOLVED (recurring from prior):** **Linear state transition by role name** — prior stasis flagged 3× manual UUID paste in BTS-130 session as BTS-128's leverage target. Shipped this session. First live use (BTS-128 → Done) was deterministic via `ticket.transition`. No manual UUID paste this session beyond initial resolver development (pre-GREEN).
- **CONDITIONAL (new, deferred):** **Local → Linear idea migration flow** — this session migrated 5 entries by hand (jq filter + rewrite + delete backup). Pattern is deterministic but ad-hoc; would become a `docs-check.sh idea-migrate-to-linear` subcommand IF downstream nodes (fucina/luxlook) need the same path. Not worth shipping yet — wait for second-occurrence evidence. Low impact; ~15 min of stochastic work per node.
- **No OTHER new candidates this session.** Triage dispatch (11 save_issue calls) was deterministic once decisions were made — parallel MCP calls with explicit stateId, not manual UUID pasting. Similarly for the dogfood close. The `ticket.transition` adoption in /idea's triage flow (AC-10) eliminated the skill's remaining use of hand-assembled save_issue payloads — this is also a determinism payoff.

## Cross-Session Patterns

- **RESOLVED: BTS-128 manual UUID paste** — prior stasis flagged it as recurring (3× in BTS-130 session). **Fix shipped in THIS PR.** The wrapper's first live use closed BTS-128 itself. Next session should NOT need to paste UUIDs for state transitions.
- **RESOLVED: BTS-120 session-stasis trap** — did NOT recur this session for the first time in 5 consecutive sessions. BTS-130's structural fix (Kind: session exclusion from validator alignment) worked. This is the second confirming data point after the prior stasis's self-proof; the pattern is now truly gone.
- **Legacy-refs-scan: `/catchup`** — 5 matches (`command-reference.md` hub-owned × 1, `foundations.md` node-specific × 4). Unchanged from prior 2 sessions. Hub-owned will resolve on next `/ccanvil-pull` on any downstream node; node-specific are committed test-fixture references.
- **Audit-session since `a626d01`: 0 findings.** Clean session with no stochastic drift captured in git diffs.
- **Permissions audit: unchanged** — 20 DANGER + 166 UNREVIEWED, same as prior two sessions. No new permission surface introduced by BTS-128 or triage flow (pure Linear + bash, all pre-granted).

## Security Review

- `security-audit.sh --files-only` final run: **PASS** (no secrets, PII, emails, dangerous file types).
- Code review explicitly checked `OP_ARG2` injection surface: the role allowlist `case` at the top of `ticket.transition)` branch blocks any non-allowlisted string from reaching the `jq -n --arg` interpolation. Confirmed safe.
- No new secrets/tokens/keys introduced. Commit diffs scanned clean.
- The `done` UUID in `.claude/ccanvil.local.json` is not sensitive (it's a Linear workflow state ID, identifiable from the Linear API via any team member) — gitignore is appropriate because the file is per-node, not because the value is secret.

## Memory Candidates

- **Migrate-then-delete for local→Linear archeology** (feedback) — Zach explicitly validated: "what is the purpose of keeping the local copy? can't we just delete them if they make it to linear?" The duplicate-marker vocabulary only makes sense pointing at Linear IDs, not at the local log (which is the SOURCE being migrated AWAY from). On Linear-routed nodes, `.ccanvil/ideas.log` is pure archeology and has no post-migration purpose. Generalizable guidance for any future "migrate captures from provider A to provider B" flow.
- **Combined `jq -e` assertion pattern for bats** (feedback/preventative) — Use `jq -e '.a == "x" and .b == "y" and .c == "z"'` instead of multiple adjacent `jq -e` lines. Avoids the BTS-127 silent-leak pattern where only the final assertion governs test exit. Used in this session's new `ticket.transition` tests successfully.
- **Dogfood payoff pattern** (project) — BTS-128 closed itself via the wrapper it shipped — first live deterministic state transition used the new primitive. Worth capturing as a pattern: when shipping a wrapper that eliminates a stochastic operation, use the wrapper's first real invocation to close the ticket that drove the ship. Validates the happy path end-to-end AND marks the determinism candidate resolved in one motion.
- **Plan-hash rebase after mid-TDD spec edit** (project) — If a spec edit happens after `/plan`, the validator immediately shows `stale-plan`. Fix is a one-line edit to `plan.md`'s `> Spec hash:` field with the new hash from `docs-check.sh status`. Not a bug, but a workflow step worth internalizing for future WARN fixes that touch the spec.
- **Blocktech "Done" state UUID** (reference) — `bc6aa160-258d-4eae-b3b5-a2575732a188`. **Now configured** in `state_ids.done` in `.claude/ccanvil.local.json`. Prior stasis had this as "not yet configured"; this session shipped the config. Still worth keeping in memory as the canonical value for downstream-node migration guidance (fucina/luxlook will need to copy it to their own local configs).

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
