# Implementation Plan: BTS-235 — ship-finalize wrapper

> Feature: bts-235-ship-finalize-wrapper
> Work: linear:BTS-235
> Created: 1777336400
> Spec hash: PLACEHOLDER
> Based on: docs/spec.md

## Objective

Add `cmd_ship_finalize` substrate + `/ship` skill that collapse the post-`/pr` sequence (title-fix → ready → merge → land → ticket-close) into one verb.

## Sequence

### Step 1: Substrate skeleton + GH_OVERRIDE wiring
- **Implement:** `cmd_ship_finalize` arg loop (PR number, --project-dir). Define `_gh()` wrapper that respects `GH_OVERRIDE` env var. Skeletal output (empty JSON).
- **Files:** `.ccanvil/scripts/docs-check.sh`.
- **Verify:** `bash docs-check.sh ship-finalize 123` returns valid JSON skeleton; missing arg exits 2.

### Step 2: AC-2 pre-flight + RED test
- **Test:** AC-2 idempotency — stubbed `gh pr view` returns `{"state":"MERGED"}` → substrate exits 0 with `pr_merged: true`. Stubbed `gh pr view` returns `OPEN` → continues to next step (which is unimplemented; expect partial output).
- **Implement:** Pre-flight `_gh pr view <N> --json state` parse. Branch on state.
- **Files:** `.ccanvil/scripts/docs-check.sh`, `hub/tests/ship-finalize.bats`.
- **Verify:** AC-2 passes.

### Step 3: AC-3 title-fix + AC-4 ready
- **Test:** Pre-flight returns OPEN; assert-pr-title call simulated (stubbed gh pr view --json title + gh pr edit). gh pr ready stubbed to success. Substrate output has `title_result` populated.
- **Implement:** Call `cmd_assert_pr_title <N> --project-dir <path>` directly (it's an internal function in the same script). Capture its JSON output. Call `_gh pr ready <N>`. Treat already-ready as success.
- **Files:** Same.
- **Verify:** AC-3 + AC-4 tests pass.

### Step 4: AC-5 merge step
- **Test:** Stubbed `gh pr merge` returns non-zero → substrate exits 1 with `step:"merge"` error in JSON.
- **Implement:** `_gh pr merge <N> --squash --delete-branch`. On non-zero exit, set `branch_deleted: false`, populate errors, exit 1.
- **Files:** Same.
- **Verify:** AC-5 passes.

### Step 5: AC-6 auto-close parse + dispatch
- **Implement:** Extract `_parse_auto_close <stdout>` helper that scans for `^AUTO-CLOSE: {.*}$` lines and emits the JSON payload (or empty). Substrate calls `cmd_land` (or stub via flag for tests), captures stdout, runs the parser, dispatches `ticket.transition done` via operations.sh + eval. On dispatch failure, queue via `cmd_idea_pending_append`.
- **Test:** Direct unit test of `_parse_auto_close` with canned stdout strings (marker present / absent / malformed). Dispatch tested via stubbed linear-query.sh.
- **Files:** Same.
- **Verify:** AC-6 passes.

### Step 6: AC-7 output schema + final wiring
- **Test:** Full happy path test — pre-flight OPEN → title fix → ready → merge → land (stubbed marker) → ticket close success. Output JSON has all expected fields.
- **Implement:** Stitch the result accumulation across steps. Format final JSON.
- **Files:** Same.
- **Verify:** Test passes.

### Step 7: AC-8 /ship skill
- **Implement:** Create `.claude/skills/ship/SKILL.md` with concise prose: takes PR number, runs substrate, renders one-line status. Skill structure mirrors `/land`'s simplicity.
- **Files:** `.claude/skills/ship/SKILL.md`, `hub/tests/ship-finalize.bats` (drift test for skill existence).
- **Verify:** Drift test passes.

### Step 8: PROJECT_TREE_SUBCOMMANDS registration
- **Implement:** Add `ship-finalize` to the array.
- **Files:** `.ccanvil/scripts/docs-check.sh` line ~39.
- **Verify:** BTS-212 reverse-direction guard passes.

### Step 9: Drift-guard + full suite
- **Test:** `grep -q "BTS-235" "$SCRIPT"`, full bats suite run.
- **Implement:** Inline BTS-235 reference in cmd_ship_finalize.
- **Files:** Same.
- **Verify:** Full suite green at ≥ 1819 + (~6-8 new tests).

### Step 10: Live dogfood
- **Test:** Use the just-shipped ship-finalize on its own PR.
- **Implement:** None.
- **Verify:** PR merges + land emits AUTO-CLOSE + ticket transitions to Done — all in one substrate call.

## Risks

- **cmd_land integration is hard to unit-test cleanly** (depends on real git history for `cmd_land_recover_branch`). Mitigation: extract `_parse_auto_close` helper for direct testing; rely on dogfood for full-pipeline validation.
- **GH_OVERRIDE pattern doesn't compose with cmd_assert_pr_title's bare `gh` calls.** If assert-pr-title doesn't honor GH_OVERRIDE, the AC-3 test cannot fully simulate. Mitigation: extend assert-pr-title to honor GH_OVERRIDE inline; or skip the test that exercises it and rely on dogfood.
- **cmd_land is not directly mockable** since it's a bash function in the same script. Mitigation: tests for AC-6 use the `_parse_auto_close` helper directly with canned stdout; full pipeline relies on dogfood.

## Definition of Done

- [ ] All 10 ACs from spec pass
- [ ] All existing tests still pass (1819 baseline → ~1825+ total)
- [ ] Drift-guard references BTS-235 in `docs-check.sh`
- [ ] BTS-235 ship dogfooded the new substrate on its own PR

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
