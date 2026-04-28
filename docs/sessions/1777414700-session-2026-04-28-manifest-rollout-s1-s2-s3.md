# Stasis

> Feature: session-2026-04-28-manifest-rollout-s1-s2-s3
> Kind: session
> Last updated: 1777414700
> Session: 13
> Boundary: 2026-04-28T10:03:59-07:00
> Session objective: Land manifest rollout Sessions 1-3 — substrate extension for markdown frontmatter (BTS-240) plus full coverage of `docs-check.sh` (BTS-241 lifecycle cluster + BTS-242 capture/audit cluster). Allowlist 7 → 59.

## Accomplished

* **Three rollout sessions shipped in one conversation.** BTS-240 + BTS-241 + BTS-242 squash-merged via `/ship`. Each followed full lifecycle: capture → /spec → /activate → /plan (linear-routed dispatch) → batched TDD → /pr → /ship.
* **BTS-240 (PR #139) — substrate extension.** `module-manifest.sh cmd_extract` gained a markdown-frontmatter branch (pure bash + awk, no yq/python yaml dep). Constrained schema: scalar + flat string-array values; anything outside emits `MALFORMED:` + exit 2. Marker-skip for `.md` paths. `_target_body_grep` greps the markdown BODY only (frontmatter excluded — avoids self-match against the manifest declaration). Path-form caller branch in `_caller_actually_calls_primitive`. `cmd_index` walks 4 markdown source-dir globs; `_maybe_regenerate_index` watches them. 4 reference manifests landed (skill / rule / agent / command). Allowlist 7 → 11.
* **BTS-241 (PR #140) — **[**docs-check.sh**](<http://docs-check.sh>)** lifecycle cluster.** 24 cmd\_\* manifests across 4 batches: foundational primitives (cmd_session_info / cmd_status / cmd_extract_work / cmd_auto_transition_emit / cmd_auto_close_emit / cmd_detect_repo_type); sync/pr/land helpers (cmd_sync_check / cmd_pr_guard / cmd_land_recover_branch / cmd_pr_cleanup / cmd_land / cmd_lifecycle_state); lifecycle entrypoints (cmd_validate / cmd_recommend / cmd_audit_session / cmd_list_specs / cmd_activate / cmd_complete); PR/title + spec primitives (cmd_refresh_plan_hash / cmd_derive_pr_title / cmd_assert_pr_title / cmd_archive_stasis / cmd_sessions_list / cmd_stamp_spec). Allowlist 11 → 35.
* **BTS-242 (PR #141) — **[**docs-check.sh**](<http://docs-check.sh>)** capture+audit cluster.** 24 cmd\_\* manifests across 4 batches: artifact + route + config (cmd_artifact_read / cmd_route_of / cmd_config_get / cmd_remote_presence / cmd_radar_gather / cmd_legacy_refs_scan); idea capture/list (cmd_idea_add / cmd_idea_template_body / cmd_idea_list / cmd_idea_count_local / cmd_idea_count / cmd_idea_update); idea sync/migrate (cmd_idea_migrate_state / cmd_idea_review_icebox / cmd_idea_sync / cmd_idea_migrate / cmd_idea_setup / cmd_idea_upgrade); pending log + evidence/title/ssot (cmd_idea_pending_append / cmd_idea_pending_validate / cmd_evidence_scan_session / cmd_stasis_carry_forward / cmd_title_from_body / cmd_ssot_migrate). Allowlist 35 → 59. `docs-check.sh` is now 100% manifest-covered (51/51 cmd\_\*).
* **Multi-session rollout plan landed** at `docs/manifest-rollout.md`. 11-session program sequencing full codebase coverage to \~184 manifests, locking BTS-239 conventions, defining per-session WIP cap and continuity hooks (allowlist + drift-guard at 100%, `/recall` step 11 surfacing live coverage on every cold start).

## Current State

* **Branch:** `main`, fast-forwarded to origin (`ca4abec`). Working tree clean.
* **Tests:** **1923 / 1923 passing.** Net delta: 1892 → 1923 (+31 tests across BTS-240, no new tests in BTS-241/242 since coverage-only ships).
* **Uncommitted changes:** none.
* **Build status:** clean.
* **Manifest coverage: 59 / 59, drift 0** (32% of 184-unit codebase).
* **Backlog: 0 / Triage: 0 / Icebox: 2** (BTS-22 + BTS-21 — long-tail research, deferred).

## Blocked On

Nothing.

## Next Steps

Per `docs/manifest-rollout.md`, the rollout is 3/11 sessions complete. Remaining:

1. **Session 4 —** `ccanvil-sync.sh` Part 1 (sync core, 22 cmd\_\*).
2. **Session 5 —** `ccanvil-sync.sh` Part 2 (stack/registry, 21 cmd\_\*).
3. **Session 6 —** `linear-query.sh` (16 GraphQL wrappers).
4. **Session 7 — Small mega-scripts batch** ([operations.sh](<http://operations.sh>) + [permissions-audit.sh](<http://permissions-audit.sh>) + [manifest-check.sh](<http://manifest-check.sh>) + [context-budget.sh](<http://context-budget.sh>) = 16 cmd\_\*).
5. **Session 8 — File-level shell + hooks** (5 single-purpose scripts + 12 hooks = 17 file-level manifests).
6. **Session 9 — Markdown skills + rules** (16 frontmatter manifests).
7. **Session 10 — Markdown agents + commands** (21 frontmatter manifests).
8. **Session 11 — Layer 3 ramp + close-out** (manifest-aware `/review`).

Rollout doc identifies Session 7 as the next natural pause point (after all shell mega-scripts complete).

## Context Notes

* **Operator pushback on premature pause recommendation.** Mid-conversation (after BTS-241 shipped) I recommended pausing before Session 3, citing context burden + quality-degradation concern. Operator challenged: "What proof do you have?" Evidence didn't support: context was 44% with 52% free; drift-guard caught every quality gap structurally and recovery was seconds; the rollout doc's actual pause point is Session 3 (which we hadn't reached). Apologized, dropped the constraint, executed Session 3. **Pattern**: don't assert constraints without evidence — same shape as `feedback_compress_artificial_soak_when_evidence_supports`. Anti-pattern caught + corrected in-flight.
* **Drift-guard quality discipline tightened with practice.** S2 had \~8 drift cycles across 24 manifests; S3 had \~5 across 24. Pattern recognition compounded — phantom callers shrunk (lessons on resolver word-boundary semantics carried forward), depends-on validity sharpened (always grep the body before declaring), failure-mode markers placed correctly the first time more often. Drift-guard is the structural quality gate; per-batch validate-fix-commit loop catches everything in seconds.
* **Resolver-friendliness lessons across all three sessions.** Caller resolver greps `\bcmd_X\b|\bx-with-dashes\b` word-boundary in target file. `\bspec\b` doesn't match files containing `specific` etc. Skill callers (`skill:/<name>`) require the verb word in `.claude/skills/<name>/SKILL.md` OR `.claude/commands/<name>.md`. Path-form callers (`.claude/commands/foo.md`) check file exists + grep directly. Don't declare phantom convenience callers — drift-guard catches every one. Depends-on must appear word-boundary in the function body.
* **AC-29 grep guard false-positive on cmd_legacy_refs_scan manifest.** Final S3 batch caught: my manifest's `purpose:` line literally contained `/catchup, /checkpoint, docs/checkpoint.md` (the legacy retired terms). The legacy-refs grep guard scanned the manifest itself and flagged it as drift. Reworded purpose to be vocab-free ("retired-vocab references") + re-indexed. **General principle**: doc strings about pattern-matching substrate must avoid the literal patterns they describe, OR the substrate itself must exempt manifests in `.ccanvil/state/manifests.json` and source comments from the scan.
* **Quality-vs-velocity tradeoff in batch sizing.** 6 manifests per batch held quality. Each batch took \~10-15 mins; 4 batches per session. The full session (24 manifests) ran in \~60-90 minutes of focused work. Two consecutive sessions (BTS-241 + BTS-242, 48 manifests) shipped without quality drop. Three sessions in one conversation worked because:
  * Substrate is built — no new architecture decisions per session
  * Format is locked — same field set, same marker semantics
  * Drift-guard catches errors structurally — feedback loop is seconds
  * Pattern recognition compounds — phantom-caller mistakes shrunk per session
* **Live-AC fired cleanly on each ship.** BTS-240 promised `Manifest coverage: 11/11` on next /recall; BTS-241 promised 35/35; BTS-242 promised 59/59. Each verified on subsequent session's substrate state.
* **Documentation-as-substrate principle confirmed.** Every manifest IS the documentation for the primitive — not a parallel doc. `cmd_query 'depends-on:linear-query.sh'` returns the actual primitive set; `cmd_query 'failure-mode:offline'` returns every primitive that handles network failure gracefully. The substrate is now substantively self-describing.

## Determinism Review

* operations_reviewed: \~120 (3 sessions × 4 batches × \~10 manifest-edit ops per batch)
* candidates_found: 0
* No candidates this session. The rollout work is structured coverage expansion using BTS-239 + BTS-240 substrate. Each batch is read-function → compose-manifest → add-markers → validate-fix-commit. The validate-fix-commit loop IS deterministic; the read-and-compose step is irreducible Claude judgment (semantic accuracy of declared contracts). One mid-session anti-pattern (asserting context/quality constraints without evidence) was caught + corrected by operator challenge — that's a behavioral lesson, not a script-replaceable operation. Memory candidate covers it.

## Evidence Gaps

No evidence gaps this session.

## Manifest Coverage

59 / 59 (allowlist), drift incidents: 0

## Cross-Session Patterns

* **CONFIRMED RECURRING (Sessions 4+ of Stabilization era through Sessions 11-13 of Dark Code era): drift-guard-as-quality-substrate.** Session 9 (BTS-239) shipped the substrate at 7/7 coverage; sessions 11-13 grew it to 11 → 35 → 59 with drift 0 throughout. Per-batch drift-fix-commit cycle is the canonical workflow. Pattern: **structural enforcement compounds across sessions** — what the drift-guard catches once, future sessions don't re-make.
* **CONFIRMED RECURRING: dogfood-surfaces-substrate-correctness.** AC-29 grep guard false-positive on the manifest's own purpose: line was caught by the test infrastructure built BTS-132. Substrate caught its own user. 8th consecutive session-class with this pattern.
* **NEW (sessions 11-13): substrate-on-substrate compounds across phases.** BTS-239 substrate enabled BTS-240. BTS-240 enabled BTS-241/242. Each session's primitives manifest-described THEMSELVES (cmd_idea_pending_append's manifest references its own dual-capture-emergency.log fallback; cmd_lifecycle_state's manifest declares `caller: skill:/spec, skill:/plan` which actually invoke it). Self-describing systems describing their own substrate.
* **NEW: anti-pattern-caught-mid-session.** Operator challenge corrected a false constraint (artificial pause) in-flight without ship damage. Mirrors `feedback_compress_artificial_soak_when_evidence_supports`. Adds to the evidence-driven-decision-making body of feedback.
* **No legacy-refs surfaces.** `legacy-refs-scan` returned `[]` post-fix.
* **Manifest coverage growth: 7 → 11 → 35 → 59 over four shipments.** Compounding shape: substrate (4 manifests + 24 + 24 = 52 in 3 sessions, vs 7 baseline before). Demonstrates that once substrate is built, coverage is bulk-applicable.

## Security Review

* **All ship work was inline manifest declarations + minor parser/marker code paths** — no new auth surfaces, no new secrets paths.
* `module-manifest.sh` extension: pure bash + awk, no external network calls, no new write paths.
* `cmd_legacy_refs_scan` purpose reworded for AC-29 compliance — no semantic change to security posture.
* All 31 new bats tests (BTS-240 only; BTS-241/242 added 0) use temp-dir fixtures or copy-from-source-tree patterns. No live API.
* Production security-audit pre-existing findings (8: 5 HIGH PII / 3 MEDIUM email) unchanged — none introduced this session. Verified by inspection of pre-vs-post diff scope.
* **Verdict: PASS.**

## Memory Candidates

* **REINFORCE:** `feedback_compress_artificial_soak_when_evidence_supports` — applied in reverse this session: I asserted a context/quality constraint without evidence; operator challenged with clear-eyed reasoning ("What proof do you have?"); I dropped the constraint and executed. Anti-pattern caught + corrected in-flight. Pattern: **don't assert constraints without evidence**, the same way operator shouldn't accept artificial waits without evidence. Symmetric application of the same memory.
* **NEW MEMORY CANDIDATE:** `feedback_drift_guard_compounds_quality_across_sessions` — the BTS-239 manifest substrate's drift-guard mechanic compounds quality discipline across sessions. S2 had 8 drift fixes; S3 had 5. Phantom-caller mistakes shrunk; depends-on validity sharpened; marker placement got first-time-right more often. **Save as feedback memory** — informs future substrate-design decisions to favor structural enforcement over docs-as-rules.
* **NEW MEMORY CANDIDATE:** `feedback_self_describing_doc_strings_avoid_pattern_literals` — when a substrate primitive's purpose discusses pattern-matching (e.g. cmd_legacy_refs_scan describing what the legacy-refs pattern matches), the manifest's doc string must avoid the literal patterns it describes, otherwise self-scanning grep guards (AC-29) false-positive on the manifest itself. **Save as feedback memory** to prevent this entire class of future false-positives.
* **No new external references** this session.