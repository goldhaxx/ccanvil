# Stasis: session-2026-05-12-bts-327-fresh-mode-claudemd-template-ship

> Feature: session-2026-05-12-bts-327-fresh-mode-claudemd-template-ship
> Kind: session
> Last updated: 1778646877
> Session: 50
> Boundary: 2026-05-12T18:28:28-07:00
> Session objective: Triage 8 session-49 captures, then ship BTS-327 (the last P2 in the original Onboarding & Hub/Spoke Separation cluster) to empirically converge the active theme.

## Accomplished

Session 50 — clean one-feature ship + idea-triage pass. Active theme empirically converges.

* **8 Triage items promoted** to Backlog in one batched dispatch. BTS-452 (P3), 453 (P2), 454 (P3), 457 (P3), 458 (P3), 459 (P3), 460 (P2), 461 (P3). Two P2s land in the queue: theme-aligned BTS-460 (hub/node separation) and next-theme anchor BTS-453 (stacks-as-templates parent).
* **BTS-327 shipped end-to-end** — fresh-mode CLAUDE.md template wedge. Spec → activate → plan → 6 TDD steps → /review → /pr → /ship. Substrate change: new `.ccanvil/templates/CLAUDE.md.fresh` (placeholder + byte-mirrored hub-managed section), new `hub_source` plan-entry field on init-preflight, consumption in init-apply. Other modes (mature-repo, partial-ccanvil, source-no-git, already-initialized) unchanged. PR #182 merged on `6c26e3c`. BTS-327 → Done.
* **/review surfaced two WARNs, both addressed:**
  * WARN-1 (BRE-dot regex hole in AC-1 placeholder asserts) — fixed in same PR via `grep -qxF`.
  * WARN-2 (`hub_source` plan-field name shadows lockfile `hub_source` key) — captured as **BTS-464**, filed as sub of BTS-327. Non-blocking readability debt.
* **Active theme "Onboarding & Hub/Spoke Separation" empirically converges.** Theme exit criteria from roadmap: "new-node onboarding produces correct + complete config in one operator command (no manual jq, no per-file pull loops, no auth-discovery friction)." BTS-327 was the last P2 in the original cluster. The remaining P2s (BTS-337/314/312/460) are scope ramps from this session's captures or follow-up substrate hardening, not original theme blockers.

## Current State

* **Branch:** `main` (clean, fast-forwarded through `6c26e3c`)
* **Tests:** 2259 / 2259 (parallel) — last invocation pre-merge; BTS-118 single-invocation discipline observed.
* **Uncommitted changes:** none.
* **Build status:** clean. Manifest 194/194, drift 0.

## Blocked On

Nothing.

## Next Steps

**Operator's call — three live threads:**

1. **Pivot to next theme.** Two strong candidates:
   * **"Simplicity through Leverage" / personality packs** (sketched in roadmap §Next Theme Direction, not yet committed) — green-field major capability; Musk/Bezos/Jobs/etc. as pluggable node-level packs.
   * **Stacks effort (BTS-453 tree)** — three concrete sub-issues ready: BTS-454 (harden one-shot template guarantee — smallest first ship), BTS-457 (stack-inventory verb), BTS-458 (bundled stack library, 3 stacks). BTS-459 (codify sub-issue pattern) is independent + small.
2. **Theme-adjacent ramp.** Within the converged Onboarding theme, BTS-460 (hub/node separation: rules describe behavior, nodes describe implementation) is the natural follow-on — captured this session, P2-promoted. Smaller than starting a new theme.
3. **Triage backlog:** 1 untriaged item (BTS-464, the WARN-2 capture). Trivial pass.

## Context Notes

* **The /pr → /ship handoff worked exactly as designed.** `/pr` left the PR ready with title + body + lifecycle docs archived; `/ship 182` ran ship-finalize cleanly — title assert (no-op, already-correct), merge, branch delete, land, auto-close. No manual intervention between phases. BTS-235 substrate behavior validated by use.
* **The new** `hub_source` **plan-entry field is the right abstraction shape but has a naming collision** with the lockfile's top-level `hub_source` key (absolute hub directory path). Different documents, never collide at runtime, but a reader of `cmd_init_apply`'s source-resolution block has to mentally track two `hub_source` concepts. BTS-464 captures the rename to `template_source` / `source_override`. Trivial follow-up.
* **The hub-managed-mirror in** `CLAUDE.md.fresh` **is a deliberate first-ship tradeoff.** The template embeds a byte copy of the hub's `CLAUDE.md` hub-managed section. AC-1 bats test diffs them on every test run — catches drift at CI time, NOT at edit time. Spec acknowledged this; review surfaced it again as INFO; this stasis flags `template-mirror-sync` as a determinism candidate.
* **Loop-based wait pattern worked well** for the long-running parallel bats suite (\~30min). One ScheduleWakeup heartbeat (270s) + task-completion notifications kept context warm without polling. The first-fire test failure surfaced 11 fails (6 ccanvil-sync.bats fixture gap + 5 manifest drift-guard failures from missing inline `@failure-mode:` marker). Both fixed in two focused edits. Subsequent runs: clean.
* **TDD slice order matched the plan exactly** — AC-7 (error path) first as smallest test, then AC-1 (template content), AC-2 (preflight emission), AC-3+AC-6 (apply), AC-5 (regression for other modes), AC-4+AC-8 (regression). Each step red → green → next. No back-and-forth, no skipped steps.

## Determinism Review

operations_reviewed: 11
candidates_found: 1

* **template-mirror-sync**: Claude manually composed `.ccanvil/templates/CLAUDE.md.fresh`'s hub-managed section by running `awk 'NR>=46' CLAUDE.md > /tmp/...` then `cat >> CLAUDE.md.fresh` — verbatim shell stitching of bytes from one file to another. Should be a substrate verb `template-mirror-sync` that regenerates the template's hub-managed section from the canonical `CLAUDE.md`, OR a pre-commit drift-guard that diffs the two hub-managed sections and refuses commits when they diverge. Today's bats AC-1 test catches drift at CI time, which is acceptable but moves the cost from authoring to discovery. Impact: medium — low frequency (hub-managed section edits are rare), but compounds risk over time as future hub-managed edits forget to propagate.

## Evidence Gaps

* BTS-461 — [guard-workspace.sh](<http://guard-workspace.sh>): refine slash-prefix detection to avoid false-positives on doc-body URL paths — missing-evidence-anchors

## Manifest Coverage

194 / 194 (allowlist), drift incidents: 0

## Cross-Session Patterns

Session 49 (strategic-reset, 0 ships, 11 captures) → Session 50 (1 ship, 1 capture, 8 triage promotes). The pattern shift: 49 surfaced strategic captures; 50 drained the theme. Healthy rhythm.

Recurring patterns from prior stasis:

* `feedback_shape_gate_narrative_cascade` — did NOT fire this session. No PreToolUse pattern-hook collisions with prose. (Prior session hit it twice; this session was disciplined.)
* **batch-idea-create** carry-forward from session 49 — did NOT recur. Only one Linear capture this session (BTS-464), single ticket via direct http path. No batch operation to expose the failure mode.
* **stack-pattern-fleet-scan** carry-forward from session 49 — did NOT recur. No fleet-scanning work this session.

`legacy-refs-scan`: clean. `audit-session`: 7 findings (2 `cp`, 5 `git-C`); all false-positives from the bats test fixture (`hub/tests/ccanvil-sync.bats` and the BTS-327 probe scripts use `cp` and `git -C "$NODE"` in standard test-setup patterns).

## Security Review

PASS. /review's security-audit step ran on the working tree pre-commit; 17 findings, ALL pre-existing on archived `docs/sessions/`, `docs/specs/`, `hub/meta/operations.md`. ZERO findings on the 5 BTS-327-touched files. No secrets, tokens, PII, or credentials introduced.

## Memory Candidates

* `feedback_brief_grep_qx_unescaped_dot_silent_pass` — `grep -qx '\[Foo.Bar\]'` under BRE matches `[FooXBar]` because the unescaped `.` is any-char. For literal-line drift-guard tests, use `grep -qxF` (fixed-string) or escape the dot. /review surfaced this in BTS-327's AC-1 placeholder asserts. Project-pattern; applies broadly to bats tests asserting literal placeholder presence.
* `feedback_ship_finalize_validates_substrate_design_by_use` — `/pr` → `/ship <N>` handoff worked frictionlessly end-to-end on first use of the canonical flow this session. BTS-235 substrate (ship-finalize) collapsed 4-5 manual steps into one verb with no surprises. Confirms substrate-design-by-use: shipping a primitive AND using it in the next ship is a tighter feedback loop than fixture-only validation.
* `project_bts_327_shipped` — BTS-327 (fresh-mode CLAUDE.md template) shipped 2026-05-12 in PR #182. The original Onboarding & Hub/Spoke Separation theme is empirically converged: theme exit criteria met, no original-cluster P2s remaining. Remaining P2 backlog items (BTS-337, BTS-314, BTS-312, BTS-460) are scope ramps or follow-up substrate, not original blockers.

## Permissions Review Pending

(none — both promote-review.counts.total and check.danger are 0)