# Stasis

> Feature: session-2026-04-26-backlog-annihilation-batch-3
> Kind: session
> Last updated: 1777175400
> Session objective: continue backlog annihilation toward priority-3 zero — picked up post-/compact after the morning+afternoon batches (BTS-166/154/152/159/168/115/161/170 = 8 ships). This session shipped 4 more.

## Accomplished

**Four substrate ships, /review caught real defects on three of them:**

- **BTS-150 (P4 investigation, PR #89).** `PermissionRequest` hook with `destination: "session"` to suppress redundant exact-form persistence to `settings.local.json`. Investigation-only ticket scoped up cleanly into substrate ship: research via claude-code-guide agent (verdict `configurable`, citations to https://code.claude.com/docs/en/hooks); live-validated the `destination: "session"` field via WebFetch before building; implemented `.claude/hooks/permission-request-suppress-redundant.sh` (~75 lines) handling token-prefix / path-prefix / exact-form matching shapes; 20 bats tests covering all three plus regressions (basher, bash-language-server word-boundary). /review found 3 CONCERN (all design acknowledgements) + 2 NIT — addressed NIT 4 (hyphen-binary negative test).

- **BTS-169 (P3, PR #90).** `guard-workspace.sh` exempts pure-slash tokens (`//`, `///`, ...) from path-token scan via `[[ "$token" =~ ^/+$ ]] && continue` — eliminates the recurring jq `//` operator false-positive that bit BTS-150's flow mid-implementation. 10 bats tests covering AC-1 through AC-5 plus quoted-default edge case. /review caught wording NIT (dropped "pathological multi-slash" phrasing) and added missing test for quoted-default form.

- **BTS-171 (P3, PR #91).** Promoted the live-API-validation auto-memory into substrate. `## Live-API validation gate` section in `.claude/rules/tdd.md` (rule + why + BTS-115/170 anchors); step 6a in `/plan` skill (`.claude/commands/plan.md`); flag-list bullet in `.claude/rules/self-review.md`; one-paragraph cross-reference in `.ccanvil/guide/core-workflow.md`; 5 drift-guard bats assertions enforcing hub-managed-section bracketing. Pure-prose substrate change — /review skipped per skip-feedback memory.

- **BTS-116 (P3, PR #92).** `ccanvil-sync.sh broadcast-resolve-auto` — algorithmic resolution of `.claude/ccanvil.json` conflicts. Four-state classifier: `take-hub` (content-identical), `keep-local` (local-superset-of-hub via deep-equal-on-shared-keys + extras-only), `requires-review` (value-divergence or local-removed-keys, exit 3), `no-conflict`. Reuses `cmd_pull_apply` for actual mutation; emits structured JSON with `divergent_keys` / `removed_keys`. **/review caught a real BLOCKING bug** — `applied: true` was being emitted before `cmd_pull_apply` ran, producing a lying audit trail under any failure path. Restructured to capture exit code first, then emit. Also addressed 1 CONCERN (BTS-127 `set -e` in AC-3/AC-4) + 2 NITs.

**Day combined: 12 ships across 3 batches** (morning 8 + afternoon-pre-compact 0 + afternoon-post-compact 4). Priority-3 backlog: 10 → 3 → 1.

## Current State

- **Branch:** `main` at `aab0bd6`, in sync with origin/main.
- **Tests:** **1350 / 1350 green** via `bats-report.sh --parallel`.
- **Uncommitted changes:** none.
- **Build status:** clean.
- **Active spec:** none — between features.
- **Permissions audit:** `danger=0`, `promote-review.total=0`. Clean.
- **Linear backlog (priority-3):** 1 remaining — **BTS-162** (`/idea --parent` flag + `capture-from-context`; spec calls for scope-down to Part 1 only at /spec time).
- **Untriaged ideas:** 0. (Down from 2 at session start; both promoted to backlog and shipped: BTS-169 and BTS-171.)
- **Context budget:** Not surfaced via context-budget.sh check (script absent or returned silently); conversation length is deep — recommend `/compact` after this stasis lands.

## Blocked On

- Nothing. Four ships clean across the post-compact session; cadence held through substrate maturity.

## Next Steps

Backlog annihilation has effectively reached priority-3 zero (modulo the one remaining ticket). **Next session:**

1. **BTS-162** — `/idea --parent` flag + `capture-from-context` shorthand. Last priority-3. Two-part proposal: scope-down at /spec time to **Part 1 only** (the `--parent` flag), defer Part 2 (`capture-from-context` with auto-injected boilerplate) to a follow-up. Part 1 is ~30-line skill prose change + ~30-line operations.sh routing extension + ~40 lines of bats. Part 2 is bigger and depends on session-context plumbing that doesn't exist yet.

2. **After BTS-162 ships, drop to priority-4.** BTS-125 (MCP truncation wrapper) is the headline P4 candidate per prior stasis. The substrate is mature enough that P4 work should also be tractable.

3. **Re-evaluate icebox.** With backlog-annihilation effectively done, run `/idea review-icebox` to surface anything older than 60d that should be promoted now that the substrate is stronger than when those items were originally deferred.

## Context Notes

- **/review continues to pay for itself.** 4 ships this session, 3 ran /review. Each /review surfaced real defects: BTS-150 (1 NIT useful), BTS-169 (1 NIT useful + missing test), BTS-116 (**1 BLOCKING — applied-flag-before-mutation produced a lying audit trail under failure**). The BLOCKING-find on BTS-116 alone justifies the cost of the whole review pass — would have shipped a bug that silently leaves nodes in stale state during partial-failure scenarios. Skip-/review on pure-prose ships (BTS-171) continues to be the right call.

- **Live-validation discipline held.** BTS-150's research returned a strong verdict (`configurable` via PermissionRequest hook); per the new feedback memory, I WebFetch'd the cited URL before building to confirm the API surface really exists as documented. It did. This is exactly the discipline BTS-171 codifies. The memory worked under fire; codifying it as a rule was the meta-validation.

- **Scope-down on reveal kept BTS-150 proportionate.** The original framing was "10-15 min doc close." Research surfaced an actionable knob, so the ticket scope-creeped into a real substrate ship — but stayed tight (no broader-pattern detection beyond Bash; non-Bash tools deferred to follow-up). The /review's "design acknowledgements not bugs" framing of the 3 CONCERNs is itself the reviewer recognizing that scope.

- **BTS-169 was a self-bite.** Hit the workspace-fence `//` false-positive while running `cat .ccanvil/lockfile.json | jq '.tracked.hooks // ...'` mid-BTS-150. Sidestepped at the time, then fixed it as the next ship. Substrate maturity continues to compound.

- **Auto-mode worked clean.** "approve" / "go" / "continue" for the major transitions; the model picked tickets autonomously when prompted with "continue". Zach's implicit feedback: trust the scope judgment when supported by review+tests.

## Determinism Review

- **operations_reviewed:** ~22 (4 ticket lifecycles × ~5 lifecycle ops, plus /idea triage dispatches, WebFetch verifications, /review dispatches, security audit, full-suite runs).
- **candidates_found:** 0.

No candidates this session. Every stochastic operation either was judgment-only by design (/review, WebFetch verification of an external doc) or rode existing deterministic substrate (lifecycle dispatch via docs-check.sh + ccanvil-sync.sh; ticket transitions via the BTS-128/164 http resolver; /idea triage via the BTS-166 http substrate). The session's substrate-improving ships (BTS-150 hook, BTS-169 fence fix, BTS-171 rule, BTS-116 conflict resolver) were themselves the determinism work.

## Cross-Session Patterns

- **CONFIRMED RECURRING: /review-finds-real-defects on substrate work.** Three sessions in a row now: morning batch (4 of 6 substrate ships, /review surfaced 3-5 concerns each), afternoon-pre-compact batch (2 of 2, 3-4 concerns each), this batch (3 of 4 ran /review, all surfaced real findings — and BTS-116's was a true BLOCKING bug, not a NIT). Pattern is stable across substrate-touching diffs. The skip-/review rule (pure-prose only, drift-guard tests sufficient) continues to hold.

- **CONFIRMED CLOSED: stub-only-tests-miss-live-API-contract-bugs.** This pattern fed BTS-171 directly — the rule is now in `tdd.md`, the skill prose, the self-review checklist, and the core-workflow guide. Drift-guard tests assert the rule's literal presence. Auto-memory remains in place as a redundant safety net. Three-incident threshold reached (BTS-115 dual-capture, BTS-170 filter shape, BTS-150 near-miss); pattern is now substrate-enforced rather than memory-enforced.

- **CONFIRMED CLOSED: workspace-fence `//` false-positive.** BTS-169 shipped this session. Hit it once during BTS-150 (cat-piped jq); fix is in main as of `95a7792`. Pattern eliminated.

- **CONFIRMED RECURRING: substrate compounding.** BTS-150 leaned on BTS-149's promote-review classifier as the cleanup safety net. BTS-116 leaned on BTS-128/164's `cmd_pull_apply` for actual mutation. BTS-171 leaned on the BTS-115 dual-capture path being already in place. Each ship makes the next ship cheaper. Validated again across this batch.

- **CONFIRMED: legacy-refs-scan stays clean** (0 matches with allowlist). BTS-132 mechanism continues to hold across sessions.

- **CONFIRMED: dogfood-close cultural invariant.** BTS-150, BTS-169, BTS-171, BTS-116 — all auto-closed on land via the BTS-128/164 substrate.

## Security Review

- **Four ships, all hub-layer changes.** No new external attack surface introduced.
- BTS-150: new hook reads `.claude/settings.json` (read-only) and pattern-matches Bash command strings; no shell expansion of user input; emits JSON via `jq -n --arg`. PreToolUse guards (`guard-destructive.sh`, `guard-workspace.sh`) still gate actual execution — the hook only suppresses the prompt-and-persist behavior.
- BTS-169: a regex-skip on tokens already inside the path scan; reduces guard surface only for non-path tokens. Existing fence still blocks real outside-workspace paths (AC-2 / AC-4 explicit regression-guards).
- BTS-171: pure-prose / drift-guard test diffs only; zero attack surface.
- BTS-116: new subcommand reads `.claude/ccanvil.json` files via `jq -n --slurpfile`, computes structural diff; mutation rides existing `cmd_pull_apply`. No new mutation primitives.
- `security-audit.sh --files-only`: PASS.
- Verdict: **PASS**.

## Memory Candidates

- **REINFORCE existing memory: live-validate plan-flagged API risks before commit.** Validated under fire on BTS-150 — the discipline held; the verdict was confirmed live before building. Memory was correct AND has now been promoted to a rule (BTS-171). No update needed; the substrate change is the durable artifact.
- **REINFORCE existing memory: skip /review on trivial diffs.** Held this session for BTS-171 (pure-prose substrate); the substrate-touching ships (BTS-150, BTS-169, BTS-116) all ran /review and each found real defects. The dichotomy continues to validate.
- **REINFORCE existing memory: backlog annihilation cadence.** 4 ships in this session post-/compact = 12 across the day. Beyond the prior memory's "6-8 with substrate maturity" upper bound. Worth a small update to the existing memory: "post-substrate-maturity, 10-12 ships per *day* (across 2-3 sessions with /compact between) is sustainable when /review and live-validation discipline hold."
- **NEW potential memory: scope-up vs. scope-down on investigation tickets.** BTS-150 was tagged "10-15 min doc close" but research surfaced an actionable knob, so it scope-creeped into a real substrate ship. The implicit Zach-validation was that "approve" came back without scope-pushback. Pattern: **investigation tickets that surface an actionable mechanism should ship the mechanism in the same flow rather than deferring**, provided the implementation stays tight (one tool family, narrow scope, drift-guard tests). The cost of a follow-up ticket exceeds the cost of one extra hour of implementation when the substrate is in hand. Worth memorializing as `feedback_investigation_ship_when_actionable.md` if a third occurrence validates.

Memories to save in this stasis: **no new memories.** The existing live-validate memory is now substrate-enforced (BTS-171); reinforcing it as memory is redundant. The "investigation-ship-when-actionable" insight is one occurrence — wait for a second before promoting to memory.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
