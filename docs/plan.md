# Implementation Plan: drift-watchdog per-create self-verification

> Feature: bts-200-watchdog-self-verification
> Work: linear:BTS-200
> Created: 1777237900
> Spec hash: 5d4024c6
> Based on: docs/spec.md

## Objective

Close the agent-hallucination class of bug by adding programmatic per-create verification to the drift-watchdog skill body, backed by drift-guards.

## Sequence

### Step 1: Write all 7 BTS-200 drift-guards
- **Test:** Add 7 `@test "BTS-200: ..."` blocks to `hub/tests/drift-watchdog-skill.bats` covering AC-1 through AC-7.
- **Implement:** Tests are pure greps against the SKILL.md file. They will all fail until SKILL.md is updated.
- **Files:** `hub/tests/drift-watchdog-skill.bats`.
- **Verify:** Tests fail with grep no-match.

### Step 2: Update drift-watchdog SKILL.md with the "Verify create landed" subsection
- **Test:** Same file from Step 1.
- **Implement:** Insert a new subsection after the existing "Per drifted node — synthesize + create" Step 4 dispatch block. Subsection includes: verify command, label assertion (jq filter), failure path (idea-pending-append), non-trust directive, network-error fallback, and BTS-200/BTS-21 anchors.
- **Files:** `.claude/skills/drift-watchdog/SKILL.md`.
- **Verify:** All 7 BTS-200 drift-guards pass. Existing 17 guards still pass.

### Step 3: Full-suite regression check
- **Verify:** `bash .ccanvil/scripts/bats-report.sh --parallel` shows total = 1568 + 7 = 1575, FAIL=0.

## Risks

- **Skill prose drift.** The "Verify create landed" subsection is prose, so a future hub edit could silently delete it. Mitigation: the 7 drift-guards explicitly grep for each piece of the protocol — if any one is removed, a guard fails.
- **Heuristic vs. live verification.** The skill is prose; the agent must actually run the get-issue command. Drift-guards enforce that the prose is correct, but cannot enforce that the agent obeys it. The skill body's `CRITICAL EXECUTION CONTRACT` preamble already addresses execution discipline. Combined with the new directive, this is the prose-level best.

## Definition of Done

- [ ] All 8 acceptance criteria from spec pass
- [ ] All existing tests still pass
- [ ] Trivial diff — pure prose update + drift-guards. Skip `/review` per `feedback_skip_review_on_trivial_diffs`.
