# Implementation Plan: Capture-time evidence requirement for bug reports

> Feature: bts-201-evidence-required-captures
> Work: linear:BTS-201
> Created: 1777236400
> Spec hash: f1cc7806
> Based on: docs/spec.md

## Objective

Make hypothesis-shaped bug captures impossible — close the failure mode that produced BTS-198 by requiring evidence anchors at capture time and surfacing prior gaps at session boundaries.

## Sequence

### Step 1: Write the rule file
- **Test:** Drift-guard test in `hub/tests/evidence-required-protocol.bats` asserting `.claude/rules/evidence-required-for-captures.md` exists, contains the four anchor names (`Command:`, `Output:`, `Exit:`, `Reproduce:`), the `DIAGNOSE:` and `FIX:` titling literals, and a reference to BTS-198/BTS-201.
- **Implement:** Create `.claude/rules/evidence-required-for-captures.md` with the protocol — what counts as evidence, the four anchors, the DIAGNOSE-vs-FIX convention, and one anchored example (BTS-198).
- **Files:** `.claude/rules/evidence-required-for-captures.md` (new); `hub/tests/evidence-required-protocol.bats` (new — start file with this test).
- **Verify:** New bats file runs and passes.

### Step 2: Update `/idea` skill — Step 0.5 evidence gate
- **Test:** Add drift-guards to `evidence-required-protocol.bats` asserting `.claude/skills/idea/SKILL.md` contains: (a) the heuristic regex literal, (b) all four anchor names line-leading, (c) reference to `evidence-required-for-captures` rule, (d) `DIAGNOSE:` titling instruction.
- **Implement:** Insert "Step 0.5 — evidence gate for bug-shape captures" between Step 0 (capture flags) and Step 1 (title generation). Body documents the heuristic regex (case-insensitive: `fail|false[- ]positive|broken|errored?|blocked by|doesn'?t work|crashes?|hang(s|ing)?`), the four anchors, the refusal flow, and the `DIAGNOSE:` alternative.
- **Files:** `.claude/skills/idea/SKILL.md`.
- **Verify:** Drift-guards pass.

### Step 3: Implement `evidence-scan-session` substrate primitive
- **Test:** New `hub/tests/evidence-scan-session.bats` with five cases: (a) zero captures → `{evidence_gaps: [], scanned: 0}`; (b) one bug-shape capture missing anchors → one gap with reason `missing-evidence-anchors`; (c) bug-shape capture with all four anchors → zero gaps; (d) `DIAGNOSE:`-titled capture → exempt; (e) malformed upstream JSON → exit non-zero.
- **Implement:** Add `evidence-scan-session` subcommand to `.ccanvil/scripts/docs-check.sh`. Accepts `--since <commit>`, `--project-dir <path>`. Resolves `idea.list` via `operations.sh`, filters captures by createdAt > commit-time (or 24h fallback when --since unresolvable), greps title against bug-shape regex, greps body for anchors, emits JSON `{evidence_gaps, scanned}`. Tests use a stubbed `operations.sh` resolution that returns canned JSON arrays — no live Linear calls.
- **Files:** `.ccanvil/scripts/docs-check.sh` (new subcommand); `hub/tests/evidence-scan-session.bats` (new).
- **Verify:** All 5 test cases pass.

### Step 4: Edge case — fresh-node 24h fallback
- **Test:** Add a 6th case to `evidence-scan-session.bats` (AC-11): when `--since` is unresolvable (e.g., empty commit, no prior stasis), the scan emits `{..., fallback: "24h"}` and uses 24h-ago as the floor.
- **Implement:** Add fallback logic to `evidence-scan-session` — if --since cannot be parsed to an epoch via `git log -1 --format=%ct`, default to `now - 86400` and add `fallback: "24h"` to output.
- **Files:** `.ccanvil/scripts/docs-check.sh`; `hub/tests/evidence-scan-session.bats`.
- **Verify:** New test passes; existing 5 still pass.

### Step 5: Update `/stasis` skill — wire scan + write `## Evidence Gaps`
- **Test:** Drift-guard in `evidence-required-protocol.bats` asserting `.claude/skills/stasis/SKILL.md` contains: (a) `evidence-scan-session` invocation, (b) `## Evidence Gaps` section reference, (c) the empty-state literal `No evidence gaps this session.`, (d) reference to `evidence-required-for-captures` rule.
- **Implement:** Add a step (between data-gathering and synthesis, near the determinism review) that invokes `docs-check.sh evidence-scan-session --since <last-stasis-commit> --project-dir .` and synthesizes the `## Evidence Gaps` section in the stasis output.
- **Files:** `.claude/skills/stasis/SKILL.md`.
- **Verify:** Drift-guards pass.

### Step 6: Update stasis template
- **Test:** Drift-guard in `evidence-required-protocol.bats` asserting `.ccanvil/templates/stasis.md` includes `## Evidence Gaps` heading and the empty-state literal.
- **Implement:** Add `## Evidence Gaps` section to `.ccanvil/templates/stasis.md` with the empty-state literal `No evidence gaps this session.`.
- **Files:** `.ccanvil/templates/stasis.md`.
- **Verify:** Drift-guard passes.

### Step 7: Update `/recall` skill — surface carried-forward gaps
- **Test:** Drift-guard in `evidence-required-protocol.bats` asserting `.claude/skills/recall/SKILL.md` contains: (a) parse instruction for `## Evidence Gaps`, (b) the literal heading `**Evidence Gaps from prior session:**`, (c) the silent-omit-when-empty rule, (d) reference to `evidence-required-for-captures` rule.
- **Implement:** Add a step in the recall briefing that reads `## Evidence Gaps` from `docs/stasis.md`, omits the section silently when content matches the empty-state literal, otherwise renders it under the heading with one line per gap.
- **Files:** `.claude/skills/recall/SKILL.md`.
- **Verify:** Drift-guards pass.

### Step 8: Cross-skill integration test
- **Test:** Add a final integration test in `evidence-required-protocol.bats`: assert all three skill files (`idea`, `stasis`, `recall`) reference the rule file by name (literal `evidence-required-for-captures`) — confirms the protocol is wired end-to-end.
- **Implement:** N/A — verification step only; if any skill is missing the reference, fail and fix in that skill.
- **Files:** `hub/tests/evidence-required-protocol.bats`.
- **Verify:** Test passes; full bats suite still green.

### Step 9: Update preset documentation
- **Implement:** Update `.ccanvil/guide/skills.md` (or wherever `/idea`, `/stasis`, `/recall` are documented) with a one-line cross-reference to the new rule. Update the relevant section of `CLAUDE.md` if a "Do Not" entry is warranted (e.g., "Do not log fix-shape bug captures without evidence anchors").
- **Files:** `.ccanvil/guide/*.md` (whichever currently documents the three skills); `CLAUDE.md` (hub section).
- **Verify:** Documentation references the rule; drift-guard against `.ccanvil/guide/` if pattern exists in repo, otherwise visual review.

## Risks

- **Heuristic false-positives.** The bug-shape regex is broad (`fail|broken|...`). Captures whose bodies use these words technically (e.g., "the test FAILS when X" in a feature spec) will be flagged. Mitigation: the operator can always title with `DIAGNOSE:` to bypass, or add the four anchors when the body genuinely is a bug. Out-of-scope refinement is acceptable per the spec.
- **`evidence-scan-session` performance.** Pulling all session captures from Linear via `idea.list` could be slow on large workspaces. Mitigation: the scan is bounded to "since last stasis" (typically <24h). Falls back to 24h on first-stasis nodes. No paging needed at single-user scale.
- **Skill prose drift across the three skills.** The protocol is referenced in three places; future hub edits could silently drop one. Mitigation: AC-9 drift-guard explicitly tests all three skills carry the rule reference (Step 8).

## Definition of Done

- [ ] All 11 acceptance criteria from spec pass
- [ ] All existing tests still pass (`bash .ccanvil/scripts/bats-report.sh --parallel`)
- [ ] No type errors (N/A — bash + markdown only)
- [ ] Code reviewed (run `/review`)

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
