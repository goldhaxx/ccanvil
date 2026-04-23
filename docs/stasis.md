# Stasis

> Feature: session-2026-04-22-auto-complete-spec-on-merge-ship
> Last updated: 1776909603
> Plan hash: afe13042 (post-feature session; plan lived in PR #43 and was cleaned up at merge)
> Session objective: Ship `auto-complete-spec-on-merge` end-to-end so the recurring "archive stays In Progress after PR merges" bug stops appearing in every stasis.

## Accomplished

- **Shipped PR #43 (`460c01b`)** — `auto-complete-spec-on-merge`: 8 AC across 11 TDD-style commits. 765/765 bats green, +8 new tests in `hub/tests/feature-lifecycle.bats`. Clean squash-merge, fast-forward land. Dogfooded: the feature's own PR validated the primary path — `pr-cleanup` on the feature branch transitioned `docs/specs/auto-complete-spec-on-merge.md` from In Progress → Complete automatically, the transition rode the squash-merge into main, and `land` correctly saw "already Complete" and stayed silent. Backlog moved to 40 Complete / 0 In Progress for the first time in 3 sessions.
- **New `docs-check.sh pr-cleanup` subcommand** — deterministic wrapper invoked by `/pr` step 7. Primary path: when `docs/spec.md` exists, parses feature_id from metadata and delegates to `cmd_complete` (status flip + lifecycle-doc removal + commit). Fallback path: no `docs/spec.md` → manual rm + commit with legacy message. Halts non-zero on malformed spec so `/pr` surfaces the error instead of silently pushing.
- **`cmd_land` safety net** — scans the just-landed branch for `claude/<type>/<id>` pattern; if the archive `docs/specs/<id>.md` is still `In Progress`, transitions to `Complete` + commits on main with `ALLOW_MAIN=1` + pushes. Silently skips non-claude branches. Covers edge cases where `/pr` was bypassed (PR merged from GitHub UI).
- **Cleared the lingering idea-upgrade archive** (801ad73) — ran `docs-check.sh complete idea-upgrade` before starting new work. This was the exact bug the new feature closes.
- **Triaged 6 ideas, captured 2 more** — promoted BTS-113/114/115/116/117 to Backlog with priorities (High: BTS-114 ⇒ just shipped; Medium: 113/115/116; Low: 117), dismissed BTS-78 (smoke-test artifact). Captured BTS-118 (full bats suite being run 3× in one `/pr` pipeline + general efficiency audit) and BTS-119 (Linear issue state didn't auto-close after PR merge — same class of bug as BTS-114, one level up) during the session.
- **Documentation sweep** — `command-reference.md` rows for `pr-cleanup` + updated `land` row to mention safety net. `core-workflow.md` gained a "Closing the feature (merge → auto-complete)" section describing primary path + safety net + no-op path. `/pr` skill step 7 replaced inline `rm + commit` with a single `docs-check.sh pr-cleanup` call.

## Current State

- **Branch:** `main` at `460c01b`, synced with origin
- **Tests:** 765/765 bats green at PR HEAD; post-merge on main: not re-run (no code mutation)
- **Uncommitted changes:** none on the hub
- **Build status:** clean

## Blocked On

- Nothing.

## Next Steps

1. **Mark BTS-114 as Done in Linear** (manual this session; the work it described is shipped). Triggered the BTS-119 capture — this step should auto-resolve on merge in a future session.
2. **Triage the 5 untriaged Linear ideas** (radar-gather: `ideas.new = 5`). BTS-118 and BTS-119 are among them and deserve priority assessment immediately; two of the 3 pre-existing untriaged may have been added mid-session — confirm via `/idea list --status new` or Linear filter.
3. **Pick the next feature.** Top candidates by priority now in Backlog:
   - **BTS-118** (High-impact, was captured mid-session) — stop chaining full bats suite runs + codify file-scoped bats in TDD rule. Fast win; 20-min tactical fix + an afternoon for the rule change. Directly addresses user-visible slowness (~25 min/session wasted).
   - **BTS-114 follow-up → BTS-119** (Medium-ish) — auto-close linked Linear issue on merge. Designed to use the new `pr-cleanup`/`land` hook points just landed. Small code surface, depends on persisting `> Idea:` in spec metadata.
   - **BTS-113** (Medium) — `recommend` output is stale immediately after `/stasis + /compact + /recall`. One-line fix to `cmd_recommend` conditional.

## Context Notes

- **Dogfooded closure — first of its kind.** The feature shipped this session was BTS-114, captured earlier the same session. The `/pr` flow that finalized PR #43 exercised the new `pr-cleanup` command it was introducing. The safety-net path in `cmd_land` was not exercised in production (archive was already Complete by the time land ran) — only by the bats tests. A future session that merges from the GitHub UI will exercise the safety net for real.
- **TDD cadence was wasteful.** I ran the full 765-test bats suite after every one of ~10 TDD steps when file-scoped `bats hub/tests/feature-lifecycle.bats` (~5s) would have been sufficient for 8 of those runs. Zach called this out explicitly — not normal for mature projects. Captured as BTS-118. The standard cadence is per-edit (file-scoped, <1s) → pre-commit (fast tier <10s) → on-push/PR (full suite async in CI) → pre-merge → post-merge → nightly.
- **PR title was mis-derived by activate.** `cmd_activate` derives the PR title from the first line after `## Summary` in the spec. My spec's summary is a long paragraph, so the whole paragraph became the title. Had to `gh pr edit --title` after the fact. Two fixes possible: (a) prefer an explicit `Name:` metadata field if present, (b) truncate the first-summary-line to 72 chars. Minor — capture if it becomes a pattern.
- **pr-cleanup as a wrapper** is the correct deterministic-first design: `/pr` skill prose used to run `rm + git add + git commit` inline (five shell operations). It now runs one script call. This matches the project's hierarchy rule (hook → script → command → reasoning) and shrinks the `/pr` prose surface.

## Determinism Review

- **operations_reviewed:** ~25 (validate + recall data-gather + 4 Linear saves + triage + spec + plan + 11 TDD commits + /pr + merge + land + stasis data-gather + legacy-refs pass + audit-session)
- **candidates_found:** 3

- **Full bats suite run 3× in one pipeline**: In `/pr`'s pre-flight I ran `bats hub/tests/ | tail -3 && echo --- && bats hub/tests/ | grep -cE "^ok " && bats hub/tests/ | grep -cE "^not ok "` — three full-suite invocations chained with `&&` to extract three pieces of information from what should have been one run. ~9 minutes of wall time for <1 second of unique signal. Should be: one `bats hub/tests/ | tee /tmp/bats.out`, then grep the file. Captured durably as BTS-118 (tactical part). **Impact: high** — recurs on every `/pr` invocation.
- **Full bats suite after every TDD step**: Across ~10 TDD cycles I ran the full suite every time when a file-scoped `bats hub/tests/feature-lifecycle.bats` (~5s) would have been sufficient for 8 of those runs. ~25 minutes wasted this session. Captured as BTS-118 (behavioral part — codify file-scoped bats during TDD in `.claude/rules/tdd.md`). **Impact: high** — recurs every development session, not just `/pr`.
- **Manually marking Linear issue Done post-merge**: After PR #43 merged, I told Zach "next: mark BTS-114 as Done in Linear" — exactly the kind of deterministic, recurring cleanup the session's own feature just eliminated for spec archives. Captured as BTS-119. The fix rides on the same hook point (`cmd_complete`/`cmd_land`) that shipped this session. **Impact: medium-recurring** — applies to every feature that originates from an idea.

## Cross-Session Patterns

- **RESOLVED — spec left `In Progress` after merge** (previous stasis: "RECURRING — 3rd occurrence"). This session shipped the fix and dogfooded it end-to-end. Backlog went to `in_progress: 0` for the first time in 3 sessions. Closed as a pattern.
- **RECURRING — `audit-session` still reports `line: 0` for every match.** 4th stasis in a row. All 44 findings this session are `git-C` pattern from the new bats tests — legitimate test fixtures, not stochastic-cleanup candidates. Findings remain classifiable, so impact stays minor. No fix this session.
- **RESOLVED 3/3 — ALLOW_MAIN=1 + unpushed main = divergence.** Third consecutive clean session. Push-guard held throughout; zero `ALLOW_DESTRUCTIVE=1` resets again. Pattern remains closed.
- **legacy-refs-scan: 162 total, 70 hub-owned, 92 node-specific** — identical counts to last stasis. No new introductions, no remediation. All 70 hub-owned are allowlist-covered historical archives; next `/ccanvil-pull` will propagate nothing new.
- **NEW PATTERN — stochastic bats-run cadence.** This session was the first to explicitly name the anti-pattern (via user observation), but it's almost certainly been silently burning ~25 min/session across every prior session too. Captured as BTS-118 (3-part scope). Predicted to recur until the behavioral + infrastructural fixes land.
- **NEW PATTERN — Linear issue state diverges from git reality at merge.** BTS-119 captures this. Same class as the just-RESOLVED archive-stays-In-Progress pattern, one level up. Predicted to recur on every feature that originates from an idea — count this as "first observation, will recur until BTS-119 ships."

## Security Review

**PASS.** Session diff reviewed:
- New function `cmd_pr_cleanup` (docs-check.sh): pure shell, filesystem + jq + existing cmd_complete. No network, no credentials.
- `cmd_land` safety-net block: reads spec metadata, writes archive status, commits/pushes main. All local; `ALLOW_MAIN=1` is a hook-bypass mechanism, not a secret.
- 8 new bats tests: pure fixture setup + assertions. Temp dirs, no external resources.
- Guide/command-reference/`/pr` prose updates: documentation, no secrets.
- `docs/specs/auto-complete-spec-on-merge.md`: public design doc.
- Linear captures (BTS-113–119) + triage mutations: metadata only; no secrets or PII in descriptions.
- No `.env`, token, private key, or credential file touched. Diff audit clean.

## Memory Candidates

- **Feedback (saved this session):** When asked to "add context to a ticket/doc," distill the insight — don't dump the raw transcript. Written as `feedback_distill_ticket_context.md` and linked in `MEMORY.md`.
- **Feedback candidate (new, worth saving after this stasis):** Industry-standard test-gate cadence is tiered (per-edit file-scoped → pre-commit fast tier → on-push CI background → pre-merge → post-merge → nightly). For ccanvil specifically: file-scoped `bats hub/tests/<one-file>.bats` during TDD cycles, full suite once at `/pr`. Don't run the full 765-test suite after every TDD step. Don't chain multiple `bats` invocations to extract different pieces of info from the same run.
- **Project fact (new):** `cmd_activate` derives PR title from the first non-empty line under `## Summary`. Long paragraphs become unwieldy titles — had to `gh pr edit --title` after the fact on PR #43. Workaround until fixed: write a short first line in spec summaries.
- **Project fact (new):** First dogfooded closure — a feature shipped via its own flow (PR #43's `/pr → land` cycle used the new `pr-cleanup` it introduced to transition its own spec archive). Validation without a separate test harness beyond bats.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
