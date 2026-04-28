# Implementation Plan: [docs-check.sh](<http://docs-check.sh>) capture+audit cluster manifests

> Feature: bts-242-docs-check-capture-audit-manifests
> Work: linear:BTS-242
> Created: 1777410000
> Spec hash: (n/a — coverage work)
> Based on: docs/spec.md

## Objective

Add 24 manifest blocks to remaining `cmd_*` primitives in `docs-check.sh`. Allowlist 35 → 59. After this ship `docs-check.sh` is 100% manifest-covered.

## Sequence

Four batches of \~6 each, validated and committed independently. Resolver-friendliness lessons from S2 applied (no phantom callers, depends-on word-boundary in body).

### Batch 1: artifact + route + config primitives (6)

cmd_artifact_read, cmd_route_of, cmd_config_get, cmd_remote_presence, cmd_radar_gather, cmd_legacy_refs_scan

### Batch 2: idea capture/list/triage (6)

cmd_idea_add, cmd_idea_list, cmd_idea_count, cmd_idea_count_local, cmd_idea_template_body, cmd_idea_update

### Batch 3: idea sync/migrate/setup/upgrade (6)

cmd_idea_sync, cmd_idea_migrate, cmd_idea_migrate_state, cmd_idea_setup, cmd_idea_upgrade, cmd_idea_review_icebox

### Batch 4: pending log + evidence/title/ssot (6)

cmd_idea_pending_append, cmd_idea_pending_validate, cmd_evidence_scan_session, cmd_stasis_carry_forward, cmd_title_from_body, cmd_ssot_migrate

### Step 5: rollout doc + final ship

Update `docs/manifest-rollout.md` Inventory, full bats green, /pr, /ship.

## Risks

* Volume ≈ S2 — same pattern; S2 shipped clean, so this is well-trodden.
* `cmd_radar_gather` is large — may surface many failure modes. Tighten manifest if exits exceed 5; collapse to "envelope-error" umbrella where appropriate.

## Definition of Done

- [ ] 24 manifests added with required keys + inline markers
- [ ] Allowlist 59 entries; validate clean (59/59)
- [ ] Bats 1923 baseline preserved
- [ ] Rollout inventory updated
