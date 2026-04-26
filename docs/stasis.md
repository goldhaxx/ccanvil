# Stasis

> Feature: session-2026-04-26-determinism-trifecta-ship
> Kind: session
> Last updated: 1777218200
> Session objective: post-/recall session. Sweep all three determinism candidates from prior stasis (BTS-177, BTS-178, BTS-179) into substrate ships before pivoting to BTS-22 (Docs directory strategy) next session.

## Accomplished

**Three substrate ships, all P3 determinism candidates from prior stasis swept into substrate primitives:**

- **BTS-179 (PR #100).** `idea-pending-replay` substrate primitive. Iterates `.ccanvil/ideas-pending.log` via fd-3 isolation (avoids dispatched-command stdin pollution), dispatches each entry by `op` via the http substrate, snapshot+rewrite pattern (sidesteps ts-collision class), atomic mv. Eliminates the `\n`-corruption class of bug surfaced 2026-04-26 when a real `/idea sync` flow tripped on the skill prose's `cat | echo | jq` round-trip. 15 new bats including the explicit `\n` regression. **Live-validated** against real Linear API: BTS-180 created with 11-line description, real newlines round-tripped intact. /review surfaced 4 concerns; 3 addressed (RETURN trap, stale comment, usage string), 1 rejected with test evidence (claimed `2>&1 >/dev/null` redirection bug — empirical test confirmed the idiom correctly captures stderr inside `$(...)`).

- **BTS-177 (PR #101).** `refresh-plan-hash` substrate primitive. Recomputes `docs/spec.md`'s `content_hash` and rewrites `docs/plan.md`'s `> Spec hash:` metadata line atomically (mktemp+mv). Idempotent. Errors clearly on missing spec/plan or malformed metadata. 8 new bats including a regression roundtrip (`aligned` → mutate spec → `stale-plan` → refresh → `aligned`) and a drift-guard asserting mktemp+mv. Skipped /review per cut-line — single deterministic primitive. Eliminates Claude's hand-edit on mid-flow scope expansion (the BTS-175 trap that hit on 2026-04-25).

- **BTS-178 (PR #102).** `assert-pr-title` substrate primitive. Reads live PR title via `gh pr view`, derives expected `feat(<feature-id>): <first-summary-line>` from `docs/spec.md` (or `docs/specs/<feature-id>.md` recovered from branch name post-cleanup), force-updates via `gh pr edit` on placeholder titles or missing-prefix. No-op when prefix matches — trusts user edits to suffix. 10 new bats covering all 7 ACs including post-cleanup spec recovery via real `git init` + `claude/feat/<id>` branch + archive read. **Live-validated** against PR #102 (the BTS-178 PR itself — the dogfood case): correctly recovered feature-id from branch, found archive, confirmed prefix match, no-op'd.

**Plus one /idea sync replay + 1 dogfood capture:**

- BTS-178 (PR-title placeholder repair) was the second pending entry from the prior session — replayed cleanly through the new BTS-179 primitive (when it landed). The fact that the SAME primitive being shipped also enabled the dogfood replay is itself a substrate-compounding moment.
- BTS-179 itself was captured as a determinism candidate at /idea sync time (when the `cat | echo | jq` round-trip bug surfaced). Triaged + promoted same session.

## Current State

- **Branch:** `main` at `2cf55b8`, in sync with `origin/main`.
- **Tests:** **1466 / 1466 green** via `bats-report.sh --parallel` (1448 → 1466, +18 net).
- **Uncommitted changes:** none.
- **Build status:** clean.
- **Active spec:** none — between features.
- **Permissions audit:** `danger=0`, `promote-review.total=0`. Clean.
- **Linear backlog (verified via canonical `backlog.list` http resolver — BTS-175):**
  - **BTS-22** (P3) — Docs directory strategy. Substrate-foundational. Headline ship for next session.
  - **BTS-20** (P4) — Workflow engine / deterministic state machine. `needs-research`.
  - **BTS-21** (P4) — GitHub Agentic Workflows (gh-aw) integration. `needs-research`.
- **Untriaged ideas:** 0.
- **Pending log:** empty.
- **Context budget:** not run; cadence-driven boundary recommends compaction now regardless.

## Blocked On

- Nothing. Three ships clean; cadence held; substrate now compounding noticeably.

## Next Steps

1. **BTS-22** — Docs directory strategy (P3, headline). Substrate-foundational: multi-file specs/plans/checkpoints, splitting today's monolithic `docs/spec.md` into a directory structure. Larger design surface than this session's ships; deserves its own session with fresh context.
2. **After BTS-22 ships, drop to P4** (BTS-20, BTS-21) — both `needs-research`. Either re-evaluate priority or do the research and let it inform the backlog.
3. **Re-evaluate icebox** (2 stale items: BTS-163 release primitive, BTS-165 provider-onboarding). 60+ days old. `/idea review-icebox` worth a pass between BTS-22 and the P4 batch.
4. **Address the new determinism finding** (see Determinism Review): activate-title-truncation. Small ship; would have prevented the manual title shortening on PR #102.

## Context Notes

- **Substrate compounding visibly accelerated this session.** All three ships were small (~30-50 LOC each) AND each leveraged primitives from prior ships: BTS-179 used BTS-166 + BTS-164; BTS-177 used the existing `content_hash()` function; BTS-178 used `cmd_activate`'s title-derivation logic. Each ship took ~30 minutes from spec to merge. The 3-ship batch landed in roughly the time one substrate-tier ship took two sessions ago.

- **`/review` cut-line is well-calibrated.** BTS-179 ran /review (substrate-tier with non-trivial control flow — 4 concerns, 3 addressed). BTS-177 and BTS-178 skipped /review per `feedback_skip_review_on_trivial_diffs` (single deterministic primitives, drift-guards in place) — neither surfaced defects post-merge. The cut-line "skip /review when diff has no logic complexity beyond what tests catch" is empirically correct so far. Three sessions of validation now.

- **Dogfood pattern.** BTS-178 was live-validated against PR #102 (its own PR) — the assert-pr-title substrate correctly recovered the feature-id from `claude/feat/bts-178-assert-pr-title`, read the archived spec at `docs/specs/bts-178-assert-pr-title.md`, computed expected, and confirmed prefix match with no-op. This is the "test the substrate against the very ship it's introducing" pattern. Captured as a memory candidate.

- **PR-title verbosity is a separate issue.** assert-pr-title's spec scope was placeholder repair, not title shortening. PR #102's auto-derived title was the entire spec Summary first paragraph — too long for a clean squash-merge subject. Manual `gh pr edit` was needed to shorten. New determinism candidate captured (see below).

- **Reviewer disagreement was correct on this session.** The /review on BTS-179 claimed `2>&1 >/dev/null` was a BLOCKING redirection bug. Empirical test (`bash -c 'echo OUT; echo ERR >&2' 2>&1 >/dev/null` inside `$(...)`) showed the idiom is correct — stderr IS captured because stdout starts pointing to the capture pipe. Rejected with evidence; AC-5 test independently confirmed the error field is non-empty on dispatch failure. Reviewers can be wrong; verify before adopting recommendations.

## Determinism Review

- **operations_reviewed:** ~28 (3 ticket lifecycles × ~6 lifecycle ops each, plus /idea sync replay, /idea triage, /pr orchestration, /land × 3, full-suite runs × 4, the manual PR-title shorten on #102).

- **candidates_found:** 1.

- **activate-title-truncation.** `cmd_activate` (line 983 of docs-check.sh) extracts the entire first summary line via `sed` and uses it verbatim as the PR title prefix. When the spec's Summary opens with a long multi-clause sentence (BTS-179 spec, BTS-178 spec), the resulting `feat(<feature-id>): <very long sentence>` title is too long for a clean squash-merge subject and Claude has to manually `gh pr edit` to shorten before merge. Should be `cmd_activate` truncates the extracted title at the first period or at ~80 chars (whichever comes first). Could also live as a separate `docs-check.sh derive-pr-title <spec-file>` primitive that both `cmd_activate` and `cmd_assert_pr_title` consume — would also let assert-pr-title force-shorten on a separate trip. Impact: low (cosmetic), but recurs on every PR with a verbose spec Summary, which is most of them. Captured as Linear idea below.

## Cross-Session Patterns

- **CONFIRMED RECURRING (positive — completion sweep): all three determinism candidates from the prior stasis (`f087476` → `61243dd`) shipped this session.** BTS-177 (plan-spec-hash drift), BTS-178 (PR-title repair), BTS-179 (idea-sync substrate). The "capture during stasis → ship next session" cycle is now empirically proven for substrate-tier candidates. This is the system working as designed.

- **CONFIRMED RECURRING: substrate compounding.** Each ship leveraged primitives from prior ships. Ship cost dropped from ~1 session to ~30 minutes. The pattern from prior stasis ("substrate compounding holds") continues — but with measurable acceleration.

- **CONFIRMED RECURRING: skip-/review-on-trivial-diffs validates cleanly.** BTS-177 + BTS-178 skipped /review (small substrate, drift-guards). Neither surfaced defects. Memory `feedback_skip_review_on_trivial_diffs` is empirically near-decisive — three sessions of validation.

- **NEW PATTERN: dogfood the substrate against the same session's own PR.** BTS-178 live-validated against PR #102 (its own PR). The substrate correctly handled the post-cleanup branch-name recovery + archive read path that no fixture exercised. Generalizable: when the substrate is a /pr or /land helper, run it against the current session's own artifact before merge. Captured as memory candidate.

- **No recurring legacy-refs.** legacy-refs-scan returns empty.

- **No recurring audit-session findings.** This session's audit-session flagged a `jq` and `cp` line — both inside new test files (test fixtures, not real session ops). False-positive; ignore.

## Security Review

- **Three ships.** No new external attack surface introduced.
- BTS-179: shell substrate primitive operating on a project-local file. No new auth surface (auth is already in linear-query.sh). Eval'd command strings come from `operations.sh resolve` — same trust boundary as before.
- BTS-177: file rewrite via mktemp+mv on docs/plan.md. No external surface. Atomic write.
- BTS-178: shell substrate calling `gh pr view` and `gh pr edit`. `gh` auth is the user's own session — same trust boundary as `/pr`. No credentials handled directly.
- All three substrate primitives respect the workspace fence (no paths outside the project).
- Verdict: **PASS**.

## Memory Candidates

- **NEW MEMORY: dogfood the substrate against the same session's own PR (when applicable).** When shipping a substrate primitive that operates on PRs, branches, or lifecycle artifacts, exercise it on the current session's own artifact mid-session BEFORE merge. BTS-178 live-validated against PR #102 — caught the post-cleanup branch-name recovery + archive-read path that fixtures miss. Generalizable to any /pr-adjacent or /land-adjacent substrate. Cross-link with `feedback_validate_plan_flagged_live_api` — different rule (live-API contract uncertainty) but same proportionate-response principle (run the live thing, don't trust stubs alone).

- **REINFORCE: feedback_skip_review_on_trivial_diffs is well-calibrated.** Three sessions of empirical validation. The cut-line "skip /review when diff has no logic complexity beyond what tests catch — substrate primitives, drift-guards in place, no real branching" is sound. No need to add a new memory; existing one is decisive.

- **REINFORCE: substrate-compounding cadence is real.** The 3-ship sweep this session landed in ~90 minutes total. Substrate compounding is now an observable productivity multiplier, not just a design principle. No new memory; it's reflected in the project's general state.

Memories to save: **one new memory** — `feedback_dogfood_substrate_on_own_session_pr.md`.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
