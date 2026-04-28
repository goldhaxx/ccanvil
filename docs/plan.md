# Implementation Plan: BTS-233 — /idea sync replay from emergency log

> Feature: bts-233-idea-sync-emergency-replay
> Work: linear:BTS-233
> Created: 1777335200
> Spec hash: f809f948
> Based on: docs/spec.md

## Objective

Extend `cmd_idea_pending_replay` to drain `.ccanvil/dual-capture-emergency.log` in addition to `.ccanvil/ideas-pending.log`, completing BTS-205's dual-capture resilience loop.

## Sequence

### Step 1: RED — emergency log fast path test
- **Test:** AC-3 — empty/absent emergency log → `emergency_pending: 0`. Add to new bats file `hub/tests/idea-pending-replay-emergency.bats`. Reuse helpers from existing replay bats.
- **Implement:** None — RED expected.
- **Files:** `hub/tests/idea-pending-replay-emergency.bats`.
- **Verify:** Test fails because `emergency_pending` field doesn't exist in output.

### Step 2: GREEN — refactor + add emergency drain
- **Test:** AC-3 from Step 1.
- **Implement:** In `cmd_idea_pending_replay`:
  1. Extract per-entry replay loop into helper `_replay_log_entries <log_path> <project_dir>` that emits per-entry result JSON to a results file (passed via env or arg) and returns success/fail counts.
  2. Call helper twice: once for ideas-pending.log, once for dual-capture-emergency.log.
  3. Aggregate `synced` and `failed` across both. Track per-log pending count (`pending` for ideas-pending.log, `emergency_pending` for emergency log).
  4. Emit JSON: `{synced, failed, pending, emergency_pending, entries}`.
- **Files:** `.ccanvil/scripts/docs-check.sh`.
- **Verify:** AC-3 passes.

### Step 3: AC-4 — emergency log replay success
- **Test:** Place 1 `add` entry in emergency log; stub linear-query.sh returns success. Assert `synced: 1`, `emergency_pending: 0`, log file empty.
- **Implement:** Helper from Step 2 should already handle.
- **Files:** `hub/tests/idea-pending-replay-emergency.bats`.
- **Verify:** AC-4 passes.

### Step 4: AC-5 — emergency log replay failure
- **Test:** Same setup as AC-4 but stub returns non-zero exit. Assert `failed: 1`, `emergency_pending: 1`, log file unchanged.
- **Implement:** No new code.
- **Files:** `hub/tests/idea-pending-replay-emergency.bats`.
- **Verify:** AC-5 passes.

### Step 5: AC-6 — both logs aggregated
- **Test:** 1 entry in pending, 1 entry in emergency. Stub returns success for both. Assert `synced: 2`, `pending: 0`, `emergency_pending: 0`, both logs empty.
- **Implement:** No new code.
- **Files:** `hub/tests/idea-pending-replay-emergency.bats`.
- **Verify:** AC-6 passes.

### Step 6: Drift-guard + skill prose update
- **Test:** Drift assertion `grep -q "BTS-233" "$SCRIPT"`.
- **Implement:** Inline BTS-233 reference in cmd_idea_pending_replay; add one-line note in `.claude/skills/idea/SKILL.md` Sync section about emergency-log replay.
- **Files:** `.ccanvil/scripts/docs-check.sh`, `.claude/skills/idea/SKILL.md`, `hub/tests/idea-pending-replay-emergency.bats`.
- **Verify:** All BTS-233 tests pass.

### Step 7: Full suite green
- **Test:** `bash .ccanvil/scripts/bats-report.sh --parallel`.
- **Implement:** Fix any regressions surfaced.
- **Files:** As needed.
- **Verify:** PASS/FAIL/TOTAL — total >= 1799 + 5 = 1804+. All green.

## Risks

- **Refactor risk to existing pending-log behavior.** Mitigation: existing `idea-pending-replay.bats` (~25 tests) acts as regression suite — they must all pass. The helper extraction is mechanical (move the loop body into a function); per-entry semantics are unchanged.
- **No live-API gate flagged** — substrate-level change exercised entirely through stubs that mirror BTS-179's existing pattern. Live contract for the underlying http calls (`linear-query.sh save-issue`) is already proven.

## Definition of Done

- [ ] All 8 ACs from spec pass
- [ ] All existing tests still pass (1799 baseline → 1804+ total)
- [ ] Drift-guard references BTS-233 in `docs-check.sh`
- [ ] Code reviewed (run `/review`)

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
