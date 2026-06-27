# Stasis: session-2026-06-26-bts-667-diff-vs-manifest-ship

> Feature: session-2026-06-26-bts-667-diff-vs-manifest-ship
> Kind: session
> Session: 89
> Boundary: 2026-06-26T20:04:08-07:00
> Last updated: 1782536279

## Accomplished

* **BTS-667 SHIPPED & LANDED** (PR #203, squash `d8cb969`, ticket Done). `diff-vs-manifest` (Layer-3 gate) now attributes inline `# @<marker>:` markers to a function newly DEFINED inside a diff hunk — instead of mis-charging them to the function above the hunk via git xfuncname. Two coordinated edits in `module-manifest.sh`: (1) `_diff_files_added` awk tracks `current_fn`, advancing it on a function-def line; (2) `_diff_ctx_to_primitive_id` extended to resolve the `function name` keyword form. Covers side-effect / depends-on / exit-path.
* **AC-7 dogfood:** closed the BTS-605 honest-narrow on `cmd_registry_prune_stale` — the conditional registry-write is now a declared `# side-effect:` key + inline marker; BTS-605 NOTE removed.
* Full lifecycle: /spec → critic (caught a real AC-4 detection-vs-attribution ambiguity + a false claim in the Notes) → activate → plan → 8 TDD steps (AC-1..AC-7, each red→green) → /review (2 WARNs fixed: dead `hunk_ctx`, `set -e`+status on AC-1/2; 1 deferred → BTS-674) → /pr → /ship → land.
* Memory hygiene: marked the xfuncname-bug reference RESOLVED (workarounds obsolete); compacted `MEMORY.md` 20.9KB → 14.0KB (dropped Completed-history + superseded project milestones, tightened hooks).

## Current State

* **Branch:** main (clean, synced with origin at `d8cb969`).
* **Tests:** full suite 2520 / 0 failures (this session's /pr pre-merge gate; BTS-118 single invocation). Even last session's telemetry flake passed clean.
* **Uncommitted changes:** none.
* **Build status:** clean. Manifest validate 206/206 drift 0 (cached from /review); Layer-3 self-check clean (the fix dogfooded on its own diff).

## Blocked On

Nothing.

## Next Steps

1. **BTS-612** (P2) — `ticket.transition` duplicate-relation ordering FIX. Clean substrate fix; the duplicate-state precedence is documented (reference_linear_duplicate_state_relation_precondition).
2. **Hub provider-auth trio** (BTS-597/598/599, P2) — retrofit copies hub ccanvil.json; provider-activate never sets mechanism=http; .env vs .env.local. A cluster — good multi-ship session.
3. **BTS-674** (Triage) — diff-vs-manifest post-close-brace re-attribution (this session's deferred W-2 edge).
4. **BTS-672** (Triage) — cmd_rule_resolve surface manifest_ref (BTS-666 follow-up).
5. 3 untriaged ideas — `/idea triage`.

## Context Notes

* **Critic-mode earned its keep again:** the first `/spec --review` pass caught that AC-4 was ambiguous between detection-only and positive re-attribution, AND that the Implementation Notes falsely claimed `_diff_ctx_to_primitive_id` already parsed the `function name()` form (it captures `function`, then fails on the parens). I had independently flagged the same gap in planning; the critic confirmed it and pinned the false claim. Disambiguated AC-4 to positive re-attribution + named the helper extension. Confirming pass returned PASS.
* **Fixture design:** synthetic diffs whose declared arrays are read from the real on-disk manifest via `cmd_extract`. Used `cmd_extract` (declares `writes-temp-file`) as the surrounding/xfuncname fn and `cmd_query` (declares `regenerates-index-if-stale`) as the new-def fn — neither declares the bogus test markers, so every test is falsifiable (verified red pre-fix).
* **Stale-plan self-inflicted:** I edited the spec (AC-5 count nit) AFTER computing the plan's spec-hash → `/pr` lifecycle blocked on stale-plan. Fixed by re-stamping the plan hash + re-dispatch + amend. Lesson: compute the plan's spec-hash from the FINAL spec, or re-stamp after any post-plan spec revision.
* **W-2 deferred honestly:** the fix trades the xfuncname back-attribution for a narrow new edge (markers AFTER a new fn's close brace, same hunk, stick to the new fn). Spec OoS'd close-brace handling; captured BTS-674 (1-level brace tracking — reset current_fn to the xfuncname on a column-0 close brace, strictly better than reset-to-empty).

## Determinism Review

* **operations_reviewed:** ~50 (recall, spec, 2 critic passes, activate, plan, 8 TDD steps, review, 3 commits, pr, ship, land, 2 Linear re-dispatches with override, memory compaction).
* **candidates_found:** 3.

**pr-body-render-substrate**: Claude hand-composed the PR #203 body via heredoc (Summary from spec, Test Plan from gate results, Spec excerpt from ACs). Should be `docs-check.sh pr-body-render --feature <id>`. Recurring — tracked as BTS-670. Impact: medium.

**concurrent-edit-own-caller-override**: Claude hit the concurrent-edit guard 3x this session (spec dispatch, spec re-dispatch, plan re-dispatch) and each time manually ran document-history to confirm own-caller (empty), then set the override env var. The own-caller check is computable — the guard should auto-detect own-caller divergence and skip the manual override. Recurring — tracked as BTS-563. Impact: medium.

**plan-spec-hash-refresh-on-spec-revision**: Claude manually re-stamped the plan's Spec hash after a post-plan spec revision (the AC-5 critic nit) had blocked the `/pr` stale-plan check. A re-stamp-plan-hash primitive — or an auto-refresh inside `/spec --review` when it revises the spec — would prevent the manual fix and the blocked-lifecycle detour. Impact: low.

## Evidence Gaps

* BTS-673 — Determinism: mid-pr-validate-changed-only — missing-evidence-anchors (prior session's determinism candidate; enhancement-shape, not a bug needing repro — surfaced for awareness, no action).

## Manifest Coverage

206 / 206 (allowlist), drift incidents: 0

## Permissions Review Pending

8 TRIAGE candidates from settings.local.json + 0 DANGER entries lacking rationale.

* All 8 are settings.local.json delta candidates classified TRIAGE (operator-personal MCP/Read entries from the BTS-603 split; not new this session).
  Run `/permissions-review` to triage interactively.

## Cross-Session Patterns

* **BTS-562 (legacy-refs raw-traces false-positive):** RECURRING — matches all from `.ccanvil/observability/raw-traces.jsonl` (gitignored runtime artifact). ~12th consecutive. node-specific; the gitignored-runtime-dir filter is still unshipped.
* **BTS-563 (concurrent-edit own-caller override):** RECURRING — 3 overrides this session (spec, spec-redispatch, plan-redispatch), all own-caller divergence. ~9th consecutive; substrate fix still pending (determinism candidate #2 above).
* **pr-body hand-composition (BTS-670):** RECURRING — PR #203 body hand-composed again (determinism candidate #1 above).
* audit-session since last stasis (2b6d2f4): 0 stochastic patterns (clean).

## Security Review

PASS. This session's diff ([module-manifest.sh](<http://module-manifest.sh>), [ccanvil-sync.sh](<http://ccanvil-sync.sh>), bats + 6 fixtures, lifecycle docs) carries no secrets or PII. The `/review` security-audit's 1 CRITICAL / 10 HIGH / 10 MEDIUM are ALL pre-existing in archived docs (operator-path + test-fixture secret/email patterns), none in the BTS-667 diff.

## Memory Candidates

* **No new durable candidates.** This session's learnings (critic-on-revised-spec catches real ambiguity; dogfood-on-own-diff surfaces gaps) are already covered by feedback_critic_mode_finds_real_findings_on_validated_specs + feedback_same_session_dogfood_validates_thesis. The xfuncname-bug reference was updated to RESOLVED in-session, and MEMORY.md was compacted to 14.0KB.