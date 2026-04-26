# Stasis

> Feature: session-2026-04-26-backlog-annihilation-batch-2
> Kind: session
> Last updated: 1777170900
> Session objective: continue backlog annihilation toward priority-3 zero — picked up after the morning's 6-ship batch (BTS-166/154/152/159/168/115).

## Accomplished

**Two more ships, both substrate-layer with /review caught real defects in each:**

- **BTS-161 (Normal, PR #87).** `permissions-audit.sh entry-context "<permission>"` — deterministic per-row context substrate for `/permissions-review`. JSON envelope: `{permission, source_files, matched_pattern, matched_hooks, introduced_in}`. `matched_hooks` uses heuristic leading-verb scan (`\bVERB\b`) filtered to gate-context lines (`=~` / `case ` / `*)`) so pure invocations like `INPUT=$(echo ...)` don't pollute. `introduced_in` via `git log -S` scoped to `$SETTINGS_DIR/...`. Closes the read-side per-row stochastic dance — paired with BTS-159's write-side `decision-append`. /review found 4 CONCERN: line-range-as-hull semantics → fixed (per-occurrence emission), git log path hardcoded → fixed (use $SETTINGS_DIR), AC-8 round-trip semantics overstated → noted, CWD-dependent hooks dir → noted. 20 AC tests; 1295 → 1296 green.

- **BTS-170 (Urgent fix, PR #88).** `linear-query.sh save-issue` workspace-scoped label fallback. Direct fix for the bug surfaced in this morning's BTS-115 dual-capture step. Added `--workspace-scoped` flag to `cmd_list_labels` (mutex with `--team` / `--team-id`); `cmd_save_issue` falls through to it when team-scoped lookup misses. **CRITICAL caught by /review and validated live:** the plan-flagged filter shape `{team:{null:{eq:true}}}` was rejected by Linear (`Boolean cannot represent a non boolean value`); corrected to `{team:{null:true}}` and verified live (returned 13 workspace-scoped labels including `idea`). Latent bug also surfaced: `"${label_filter[@]}"` on empty array crashed under `set -u` — fixed with safe-expand idiom (`"${arr[@]+"${arr[@]}"}"`). 10 AC tests; 1306 green.

**Substrate stack now end-to-end ergonomic.** Eight tickets in the day's combined backlog-annihilation: BTS-166 → BTS-154 → BTS-152 → BTS-159 → BTS-168 → BTS-115 → BTS-161 → BTS-170. PRs #81 through #88. Backlog dropped 10 → 3 priority-3 items.

## Current State

- **Branch:** `main` at `90c41bc`, in sync with origin/main.
- **Tests:** **1306 / 1306 green** via `bats-report.sh --parallel`.
- **Uncommitted changes:** none.
- **Build status:** clean.
- **Active spec:** none — between features.
- **Permissions audit:** `danger=0`, `promote-review.total=0`. Clean.
- **Linear backlog (priority-3):** 3 remaining — BTS-162, BTS-116, BTS-150.
- **Untriaged ideas:** 1 — likely BTS-169 (workspace-fence `//` false-positive captured at the prior stasis dual-capture step).
- **Context budget:** WARNING (6642 / 8000 aux file budget; 250k / 1M raw conversation tokens — plenty of headroom on the wire, the WARNING is the deterministic file-budget framework hitting its threshold).

## Blocked On

- Nothing. Eight ships clean across the day; the cadence is sustainable.

## Next Steps

Backlog annihilation continues next session. **Remaining priority-3 backlog (3 items):**

1. **BTS-162** — `/idea --parent` + `capture-from-context`. Two-part proposal in the ticket; biggest remaining item. Plan: scope-down at spec time — ship Part 1 (`--parent` flag) tight; defer Part 2 (`capture-from-context`) to a follow-up if it expands ship size.
2. **BTS-116** — `broadcast-resolve-auto`: algorithmic ccanvil.json conflict resolution. Untouched scope; need to read the ticket cold. Likely 45-60 min ship if scope holds.
3. **BTS-150** (P4, investigation-only) — could be closed with a documentation entry rather than a code change. Read the ticket first; if a doc-update is sufficient, ship it as a 10-15 min close to clear the priority-3 tier.

After priority-3 reaches zero, drop to priority-4 (BTS-125 MCP truncation wrapper, anything else captured during these batches). Capture-then-ship rhythm is well-established — same-session captures (BTS-168, BTS-169, BTS-170) closed within their introduction sessions.

## Context Notes

- **/review is paying for itself every time.** Both BTS-161 and BTS-170 ran /review and each caught real defects (line-range semantics, hardcoded paths, CRITICAL filter-shape bug, AC test coverage gap). Every substrate-changing diff this batch had at least one production-blocking concern that /review caught. The skip-/review rule (logic-free diffs only) continues to hold; everything substrate-touching ran it.

- **CRITICAL filter-shape lesson (BTS-170).** The plan called out the filter shape as the top risk: "the exact filter shape for 'team is null' might be `{team:{null:true}}` (boolean) or `{team:{null:{eq:true}}}` (comparator). Mitigation: at Step 1, write the test against the stub-emitted GraphQL request body and verify the filter shape in the variables. If the live API rejects, adjust." I read this. I committed without live-validating. /review caught it. **Pattern to internalize:** when the plan flags a live-API risk, the implementation must include a live-API call before commit, not just stub coverage. The stub will accept anything; only the live API tells truth. This is the second time this session category has bitten — the first was the BTS-115 dual-capture path failing live during yesterday's stasis. Both times the lesson is the same: stubs lie; APIs don't.

- **Latent bash gotcha (BTS-170 review fix).** `"${arr[@]}"` on empty array under `set -u` errors as "unbound variable" on bash 4.x. The fix is `"${arr[@]+"${arr[@]}"}"` — conditional expansion that only fires when the array is set (which it always is for a `local` declaration, but bash treats empty arrays as unset for this expansion). The original BTS-166 code had this latent bug; only the new BTS-170 AC-7 test (genuinely unscoped path via update mode) hit it. Worth memorizing.

- **AC-7 spec-vs-test divergence caught by /review.** The original AC-7 test asserted "no fallback fires when team-scoping is set" — but the spec wording was "WITHOUT team scoping." /review noticed the test was effectively duplicating AC-4. Rewrote AC-7 to use update mode (`save-issue --id BTS-XXX --labels idea`), which legitimately omits team scoping and exercises the unscoped-label-resolution path. **Pattern:** read the spec before writing the test name; if the test name's first line and the spec's first sentence describe different scenarios, you're testing the wrong thing.

- **Substrate compounding visible in real time.** BTS-161 (`entry-context`) shipped fast because BTS-159 (`decision-append`) had already mapped the per-row stochastic dance. BTS-170 (workspace-scoped fallback) shipped fast because BTS-166 had already established `linear-query.sh` as the dispatch primitive AND because /stasis dual-capture surfaced the bug live. Each ship is making the next ship cheaper. Three priority-3 items remaining feel like one or two more sessions to close.

- **Auto-mode held throughout.** "go" / "keep going" / "merge then land" worked clean. The user explicitly held annihilation mode through the stasis from this morning ("We are staying in backlog annihilation mode") — same energy carried through this batch.

## Determinism Review

- **operations_reviewed:** ~20 (2 ticket lifecycles × ~6 lifecycle ops, plus permissions check, recall, /review dispatch, security audit, manual git log -S verification, manual filter-shape live test).
- **candidates_found:** 1.

- **Plan-flagged live-API risks must include a live-validation step before commit.** During BTS-170, the plan explicitly flagged the GraphQL filter shape as risk #1 ("if the live API rejects, adjust"). I committed without live-validating; /review caught the CRITICAL. This isn't a script-replacement candidate — it's a *rule/skill candidate*: amend `.claude/rules/tdd.md` or the `/plan` skill prose so plans containing "live API" risk language emit a check at the implementation phase: "before /review, verify the risky-API call against the live endpoint." Impact: medium — substrate plans frequently flag API-shape risks; bypassing live-validation leaks bugs that stub-only tests can't catch.

## Cross-Session Patterns

- **CONFIRMED RECURRING: /review-finds-real-defects on substrate work.** Last session: 4 of 6 ships ran /review and each surfaced 3-5 real concerns. This session: 2 of 2 ships ran /review and each surfaced 3-4 real concerns. Pattern is stable — /review on substrate work returns more value than it costs. Reinforces last session's memory.
- **CONFIRMED RECURRING: stub-only tests miss live-API contract bugs.** Last session: BTS-115 dual-capture failed live (workspace-scoped label) despite passing tests. This session: BTS-170 filter shape rejected live despite stub assertions passing. Both rooted in the same gap — stubs accept anything; only live validation catches contract bugs. **This is the new highest-priority cross-session pattern.** It implies the determinism review candidate above is real and worth shipping as a rule update.
- **CONFIRMED: legacy-refs-scan stays clean** (0 matches with allowlist). BTS-132 mechanism continues to hold across sessions.
- **CONFIRMED: dogfood-close cultural invariant.** Both tickets auto-closed on land via the BTS-128/164 substrate.
- **NOT RECURRING (this session): workspace-fence `//` false-positive.** Did not surface this batch — I avoided `//`-in-jq syntax proactively. BTS-169 still open as a tracked fix.

## Security Review

- **Two ships, both hub-layer changes.** No new attack surface introduced.
- BTS-161: `entry-context` reads `.claude/hooks/*.sh` and runs `git log -S` against committed settings files — both read-only; no mutation; no input that could escape jq's safe construction.
- BTS-170: extends label resolution; new GraphQL filter is constant (`{team:{null:true}}`); no new input surface. The safe-expand fix to `"${label_filter[@]+"${label_filter[@]}"}"` is purely defensive against `set -u`, not a security control.
- `security-audit.sh --files-only`: PASS (verified twice during the session — once before each /pr).
- Verdict: **PASS**.

## Memory Candidates

- **NEW feedback memory candidate: live-validate plan-flagged API-shape risks before commit.** Two consecutive sessions surfaced the same class of bug (BTS-115 dual-capture, BTS-170 filter shape) — plans called out live-API risks; implementations relied on stubs; /review caught the contract bugs. Worth saving as: "When a plan flags a risk like 'live API may reject this shape — adjust if so', the implementation must include a live-API call BEFORE commit, not after. Stubs accept anything; only live calls verify contract." Reason: prior incidents have shown that the cycle "stub-pass → commit → /review-flags → live-test-fails → fix → recommit" is 2× the cycle of "live-test-first → commit-once."
- **REINFORCE existing memory: skip /review on trivial diffs.** Held this session for the doc-update steps in BTS-161 (command-reference.md) — but the substrate diffs ran /review and each found real defects. Memory continues to validate.
- **REINFORCE existing memory: backlog annihilation cadence.** Eight ships in this session combined with the morning's six = 8 total ships in ~6 wall-hours (with /compact + /recall in the middle). Beyond the prior memory's "4-6 per session" bound, but the pattern works when substrate is mature and review judgment is intact. Worth updating: "post-substrate-maturity, 6-8 ships per session is sustainable IF /review is held discipline AND live-API validation is mandatory for plan-flagged risks."
- **Bash gotcha: `"${arr[@]}"` on empty array crashes under `set -u`.** Fix is `"${arr[@]+"${arr[@]}"}"`. Worth a one-liner in `.claude/rules/code-quality.md` as a bash convention note. Low priority — can be a follow-up cleanup ticket if it bites again.

Memories to save in this stasis: **yes** — the live-API validation feedback is non-obvious and validated by 2 consecutive incidents. Will save as `feedback_validate_plan_flagged_live_api.md`.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
