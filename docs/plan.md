# Implementation Plan: git commit early-exit in guard hooks

> Feature: bts-151-fix-commit-msg-false-pos
> Work: linear:BTS-151
> Created: 1777155500
> Spec hash: b94c64a9
> Based on: docs/spec.md

## Objective

Add the same early-exit pattern to both `guard-destructive.sh` and `guard-workspace.sh`: when the command is `git commit` at the start (with optional env prefix), exit 0 before any further checks.

## Sequence

### Step 1: Tests (red)
- **Test:** New BTS-151 block in `guard-hooks.bats`. Tests for both hooks: AC-1..AC-10 (10 tests, mostly single-assertion).
- **Files:** `hub/tests/guard-hooks.bats`.
- **Verify:** Currently-blocking cases (AC-1: commit message with rm-rf, AC-2: commit with /stasis path) fail in red phase.

### Step 2: Add early-exit to guard-destructive.sh
- **Implement:** After the ALLOW_DESTRUCTIVE bypass at line 15, add a `git commit` shape check that exits 0.
- **Files:** `.claude/hooks/guard-destructive.sh`.

### Step 3: Add early-exit to guard-workspace.sh
- **Implement:** Same shape, after the ALLOW_OUTSIDE_WORKSPACE bypass.
- **Files:** `.claude/hooks/guard-workspace.sh`.

### Step 4: Regression sweep
- **Verify:** `bats-report.sh --parallel` clean. Lint clean.

## Risks

- **Chained destructive ops after commit (AC-9).** Documented; trade-off accepted.
- **Pattern false-negatives.** If the regex anchors too strictly, real commits with unusual env prefixes might still get blocked. Test AC-10 covers env prefix; verify with multiple variants.

## Definition of Done

- [ ] All 11 ACs pass (AC-11 = full suite)
- [ ] Lint clean
- [ ] Code reviewed via `/review`
