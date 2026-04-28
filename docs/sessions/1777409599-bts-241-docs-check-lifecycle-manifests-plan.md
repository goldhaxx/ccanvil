# Implementation Plan: [docs-check.sh](<http://docs-check.sh>) lifecycle-cluster manifests

> Feature: bts-241-docs-check-lifecycle-manifests
> Work: linear:BTS-241
> Created: 1777407500
> Spec hash: (n/a — pure coverage work)
> Based on: docs/spec.md

## Objective

Add 24 manifest blocks + inline source markers to lifecycle-cluster `cmd_*` primitives in `docs-check.sh`. Allowlist 11 → 35 with drift-guard 100%.

## Sequence

Four batches of 6 primitives each. Per-batch workflow:

1. Read each function body; enumerate input/output/side-effect/failure-mode/depends-on/caller via grep + reading.
2. Compose `# @manifest` block above the function definition.
3. Add inline `# @failure-mode: <id>` markers at each non-zero return path; `# @side-effect: <id>` markers at mutation sites.
4. Append batch entries to `.ccanvil/manifest-allowlist.txt`.
5. Run `module-manifest.sh validate`; resolve drifts before commit.
6. Commit batch (`feat(bts-241): batch N — <names>`).

### Batch 1: foundational primitives

cmd_session_info, cmd_status, cmd_extract_work, cmd_auto_transition_emit, cmd_auto_close_emit, cmd_detect_repo_type

### Batch 2: sync/pr/land helpers

cmd_sync_check, cmd_pr_guard, cmd_land_recover_branch, cmd_pr_cleanup, cmd_land, cmd_lifecycle_state

### Batch 3: lifecycle entrypoints

cmd_validate (docs-check's), cmd_recommend, cmd_audit_session, cmd_list_specs, cmd_activate, cmd_complete

### Batch 4: PR/title + spec primitives

cmd_refresh_plan_hash, cmd_derive_pr_title, cmd_assert_pr_title, cmd_archive_stasis, cmd_sessions_list, cmd_stamp_spec

### Step 5: Final wrap

Update `docs/manifest-rollout.md` Inventory table; full bats suite green; /pr; /ship.

## Risks

* **Marker placement requires reading every non-zero return path.** A missed `return 2` produces a `missing-failure-mode-marker` drift at validate. Mitigation: drift-guard catches it; iterate.
* **Caller declarations may include phantom skills.** Mitigation: `_caller_actually_calls_primitive` greps; phantom callers fail validate with `caller-not-found`. Iterate.
* **Volume of work — 24 manifests is at the per-session WIP edge.** Mitigation: batched commits + drift-guard between batches catches errors early; quality-over-speed per rollout doc Quality Bar.

## Definition of Done

- [ ] All 11 ACs from spec satisfied
- [ ] Manifest coverage 35/35, drift 0
- [ ] Bats suite still 1923 (no regression)
- [ ] Rollout inventory updated
- [ ] /review pass (if substrate-meaningful changes appear; coverage-only is typically auto-approve)
