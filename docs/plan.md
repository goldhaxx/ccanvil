# Implementation Plan: Uniform flag parsing across `docs-check.sh` subcommands

> Feature: bts-212-uniform-flag-parsing
> Work: linear:BTS-212
> Created: 1777315706
> Spec hash: a501d1eb
> Based on: docs/spec.md

## Objective

Eliminate the cryptic-downstream-tool-error class of bugs in `docs-check.sh` (BTS-218 manifestation) by making `--project-dir` and unknown-flag handling uniform across the project-tree-aware subcommand family, locked in by a drift-guard bats test.

## Sequence

Each step is one red-green-refactor cycle. Steps 1–2 are pre-test research/scaffolding; step 3 is the RED phase; steps 4–7 are GREEN; step 8 is the gate.

### Step 1: Enumerate the project-tree-aware subcommand set (research)

- **Test:** None — research only. Output is a written list inside `docs/plan.md`'s implementation notes, not code yet.
- **Implement:** Walk the dispatcher (lines ~4651–4700 of `.ccanvil/scripts/docs-check.sh`). For each subcommand, classify by reading its `cmd_*` body:
  - **Project-tree-aware** (must accept `--project-dir`): touches `docs/`, `.ccanvil/`, `.git`, or otherwise resolves a project root.
  - **Pure utility** (excluded from canonicalization): operates on stdin/stdout / formatting / takes only positional non-path args.
- **Files:** Read `.ccanvil/scripts/docs-check.sh`. No edits this step.
- **Verify:** Produce a partition. Expected ~30 project-tree-aware (status, validate, recommend, audit-session, list-specs, activate, complete, pr-cleanup, detect-repo-type, land, land-recover-branch, sync-check, pr-guard, radar-gather, idea-add, idea-list, idea-count, idea-count-local, idea-update, idea-sync, idea-pending-replay, refresh-plan-hash, archive-stasis, sessions-list, idea-review-icebox, idea-migrate-state, idea-migrate, idea-setup, idea-upgrade, legacy-refs-scan, stamp-spec, evidence-scan-session, lifecycle-state, artifact-read, artifact-write, route-of, ssot-migrate, session-info, assert-pr-title, remote-presence) and ~10 pure-utility (extract-work, auto-close-emit, auto-transition-emit, derive-pr-title, title-from-body, idea-template-body, idea-pending-validate, idea-pending-append, config-get).

### Step 2: Add `PROJECT_TREE_SUBCOMMANDS` source-of-truth array

- **Test:** None yet — the array is itself a constant referenced by the test in step 3.
- **Implement:** Add a bash array near the top of `docs-check.sh` (after the existing `DEFAULT_DOCS_DIR=` constant block), enumerating the project-tree-aware subcommand names from step 1. Include a comment block explaining what the array is for, what it's NOT for, and how to add new entries (must inherit the contract).
- **Files:** `.ccanvil/scripts/docs-check.sh` (one constant addition).
- **Verify:** `bash -c 'source .ccanvil/scripts/docs-check.sh; printf "%s\n" "${PROJECT_TREE_SUBCOMMANDS[@]}" | wc -l'` returns the expected count.
   *Caveat:* sourcing the script triggers the dispatcher tail. Use `awk '/^PROJECT_TREE_SUBCOMMANDS=\(/,/^\)$/' .ccanvil/scripts/docs-check.sh` to extract the array body for inspection without sourcing.

### Step 3 (RED): Write `hub/tests/docs-check-flags.bats`

- **Test:** A new bats file with two-shape contract per project-tree-aware subcommand:
  - **Shape A:** `bash docs-check.sh <cmd> --project-dir "$BATS_TEST_TMPDIR"` — assert exit code is 0 OR stderr matches `^Usage:` (cmd requires additional positional args). Never `dirname:` / `jq:` / etc.
  - **Shape B:** `bash docs-check.sh <cmd> --bogus-flag-xyz` — assert exit code is 2 AND stderr matches `^Usage:` AND stderr does NOT match `dirname:|jq:|sed:|awk:`.
- **Implement:** The test file extracts the `PROJECT_TREE_SUBCOMMANDS` array via `awk '/^PROJECT_TREE_SUBCOMMANDS=\(/,/^\)$/'` (same pattern as BTS-217's `_normalize_feature_to_ticket` test). Iterates the array; one assertion block per cmd. Run inside `$BATS_TEST_TMPDIR` so hub's routing config doesn't bleed in.
  - For Shape A: prepare a minimal fixture (`mkdir -p "$BATS_TEST_TMPDIR/.ccanvil/state $BATS_TEST_TMPDIR/docs"`) so cmds that read `docs/spec.md` etc. find an empty-but-valid tree.
  - For Shape B: no fixture needed — the cmd should error out before reaching project-tree access.
- **Files:** `hub/tests/docs-check-flags.bats` (new).
- **Verify:** `bash .ccanvil/scripts/bats-report.sh -f docs-check-flags` reports MANY failures (expected — most cmds haven't been patched yet). The number of failures should be ~30 (one per project-tree-aware cmd not yet patched). Confirm 7–8 cmds already pass (those that already declare `--project-dir`: session-info, refresh-plan-hash, archive-stasis, sessions-list, assert-pr-title, idea-pending-replay, ssot-migrate, idea-upgrade, route-of, artifact-read, artifact-write, evidence-scan-session — these were pre-canonicalized).

### Step 4 (GREEN): Patch the simple subcommands (Group 1)

- **Test:** Re-run `bash .ccanvil/scripts/bats-report.sh -f docs-check-flags` after each cmd patched.
- **Implement:** Patch one cmd at a time, lifting the `cmd_session_info` arg-loop pattern but with strict unknown-flag handling. Group 1 covers the easy ones:
  - `cmd_radar_gather` (line 1804) — currently positional; add full arg loop. Closes BTS-218.
  - `cmd_idea_add`, `cmd_idea_list`, `cmd_idea_count`, `cmd_idea_count_local`, `cmd_idea_update`, `cmd_idea_sync`, `cmd_idea_review_icebox`, `cmd_idea_migrate_state`, `cmd_idea_migrate`, `cmd_idea_setup` — most likely already have `*) shift ;;` patterns; replace with strict + ensure `--project-dir` parsed.
  - `cmd_legacy_refs_scan`, `cmd_stamp_spec` — single positional; add flag layer.
- **Files:** `.ccanvil/scripts/docs-check.sh` (patches throughout).
- **Verify:** Group 1 cmds now pass docs-check-flags.bats. No existing test regressions.

### Step 5 (GREEN): Patch the lifecycle subcommands (Group 2)

- **Test:** Re-run drift-guard + full lifecycle test groups (`activate.bats`, `complete.bats`, `land.bats`).
- **Implement:** Patch the lifecycle-pipeline cmds:
  - `cmd_status`, `cmd_validate`, `cmd_recommend` — position-1 docs_dir; add flag layer preserving positional.
  - `cmd_audit_session`, `cmd_list_specs` — likely already have arg loops; standardize unknown handling.
  - `cmd_activate`, `cmd_complete`, `cmd_pr_cleanup` — heavy state-mutating; preserve all existing positional shapes.
  - `cmd_detect_repo_type`, `cmd_land`, `cmd_land_recover_branch` — git-mechanic cmds; preserve.
  - `cmd_sync_check`, `cmd_pr_guard`, `cmd_remote_presence` — guard cmds.
  - `cmd_lifecycle_state` — already has `--project-dir`; verify strict unknown.
- **Files:** `.ccanvil/scripts/docs-check.sh`.
- **Verify:** Group 2 cmds pass drift-guard. **Critically:** lifecycle integration tests (activate.bats, complete.bats, land.bats, pr-cleanup.bats, lifecycle-state.bats) all still pass — backward compat for positional callers is intact.

### Step 6 (GREEN): Patch remaining subcommands (Group 3)

- **Test:** Re-run drift-guard + remaining test files.
- **Implement:** Anything not in Groups 1 or 2. Likely a small residual: any subcommand that snuck in as project-tree-aware but wasn't grouped above.
- **Files:** `.ccanvil/scripts/docs-check.sh`.
- **Verify:** All 30 project-tree-aware cmds pass docs-check-flags.bats.

### Step 7: Drift-guard reverse direction — fail if a project-tree-aware cmd is missing from the array

- **Test:** Add a final assertion in `docs-check-flags.bats`: enumerate every dispatched subcommand from the case statement (via `awk` on the dispatcher block), classify by detecting `--project-dir` parsing in the cmd body (grep), then assert each detected project-tree-aware cmd appears in `PROJECT_TREE_SUBCOMMANDS`.
- **Implement:** New bats test block in the same file. The detection heuristic: if a cmd's body contains `--project-dir)` AND is dispatched in the case statement, it should be in the array. Pure-utility cmds explicitly excluded by name list.
- **Files:** `hub/tests/docs-check-flags.bats`.
- **Verify:** Test passes. The array is now both upper-bound (test asserts every member has the contract) and lower-bound (test asserts no project-tree-aware cmd is missing).

### Step 8 (GATE): Full suite green

- **Test:** `bash .ccanvil/scripts/bats-report.sh --parallel`.
- **Implement:** N/A — verification only.
- **Files:** None.
- **Verify:** `PASS: <count>, FAIL: 0, TOTAL: <count>` with `<count>` ≥ 1712. New tests in `docs-check-flags.bats` add ~60 assertions (~30 cmds × 2 shapes) plus the reverse-direction guard, raising the total.

### Step 9: Documentation propagation (mandatory per workflow rules)

- **Test:** None — documentation only.
- **Implement:** Update preset documentation if any changes propagate to skills:
  - **Hub-wide:** if `--project-dir` usage changes anywhere in skill prose (recall, stasis, idea, radar), update `.ccanvil/guide/command-reference.md` to standardize on the canonical pattern.
  - Note in CLAUDE.md if any new convention emerges (probably not — this is substrate-internal, no user-facing API change).
- **Files:** `.ccanvil/guide/command-reference.md` (if needed); `CLAUDE.md` (probably not).
- **Verify:** Skim diff; no contradiction with existing prose.

## Risks

- **Backward-compat regression in positional callers.** `cmd_radar_gather "$DEFAULT_DOCS_DIR"` is called from inside other cmds. The arg loop must consume `--project-dir <path>` first, then fall through to legacy positional handling. Pattern: arg loop builds `$project_dir` from flag if present, else falls through to `local docs_dir="${1:-$DEFAULT_DOCS_DIR}"`. **Mitigation:** lifecycle integration tests catch this; Step 5 explicitly verifies them.
- **`PROJECT_TREE_SUBCOMMANDS` drift.** A new cmd added later might forget to inherit. **Mitigation:** Step 7's reverse-direction test fails the suite if a dispatched cmd has `--project-dir)` parsing but isn't in the array.
- **30+ patches in one PR is large.** Could introduce noise on review. **Mitigation:** group commits by concern (one commit per group: array, test, group1, group2, group3, reverse-test, docs). Reviewer can read group-by-group.
- **The `dirname` failure surface might be deeper than just argv parsing.** Some cmds compute `project_root="$(dirname "$something")"` mid-body, where `$something` could be tainted by upstream argv. **Mitigation:** if a cmd's `--project-dir` resolves cleanly at the top of the arg loop, downstream `dirname` calls receive a path, not a flag. Most failures are from `--project-dir` reaching `$1` of `dirname` directly because no arg loop existed.
- **Live-API gate not applicable.** No live-API contract risk in this work — pure substrate-internal refactor.

## Definition of Done

- [ ] All acceptance criteria from spec pass (AC-1 through AC-6)
- [ ] `bash .ccanvil/scripts/docs-check.sh status --project-dir .` succeeds (currently fails — see step 1's verify)
- [ ] `bash .ccanvil/scripts/docs-check.sh radar-gather --project-dir .` succeeds (BTS-218 closed)
- [ ] All existing tests still pass (1712 baseline preserved + ~60 new from docs-check-flags.bats)
- [ ] Code reviewed (run /review)
- [ ] BTS-218 included in PR body so Linear's auto-link closes it on merge alongside BTS-212

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
