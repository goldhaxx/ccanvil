# Feature: [linear-query.sh](<http://linear-query.sh>) provider substrate manifests

> Feature: bts-245-linear-query-substrate-manifests
> Work: linear:BTS-245
> Created: 1777427549
> Subject: [linear-query.sh](<http://linear-query.sh>) provider substrate manifests
> Status: In Progress

## Summary

Manifest rollout Session 6 per `docs/manifest-rollout.md`. Add `# @manifest` blocks for the 16 cmd\_\* in `.ccanvil/scripts/linear-query.sh` — the http-canonical Linear GraphQL substrate that all `mechanism: http` resolvers in [operations.sh](<http://operations.sh>) dispatch through. Coverage-only ship. Allowlist 102 → 118.

## Job To Be Done

**When** I extend Layer 2 coverage to the provider substrate per `.claude/rules/provider-integration.md`,
**I want to** declare 16 inline manifests + markers across `linear-query.sh` and grow the allowlist to 118,
**So that** every Linear GraphQL wrapper carries machine-readable purpose / contract / failure semantics, drift-guard catches future regressions structurally, and `/recall` reports `118 / 118, drift: 0`.

## Acceptance Criteria

- [ ] **AC-1:** All 16 cmd\_\* in scope declare a complete `# @manifest` block. Required keys present: `purpose`, `input`, `output`, `side-effect`, `failure-mode`, `contract`, `anchor`. Conditional keys declared where applicable.
- [ ] **AC-2:** Every declared `failure-mode` line has a matching `# @failure-mode: <id>` source marker at the failing return/exit line.
- [ ] **AC-3:** Every declared `side-effect` line has a matching `# @side-effect: <id>` source marker at the mutating line.
- [ ] **AC-4:** `.ccanvil/manifest-allowlist.txt` appended with 16 entries grouped under `# BTS-245 — Session 6: linear-query.sh GraphQL wrappers.` plus per-batch sub-headers.
- [ ] **AC-5:** `bash .ccanvil/scripts/module-manifest.sh validate --json` reports `coverage: 118/118` and `(drift | length) == 0`.
- [ ] **AC-6:** Bats suite passes — no regression. No new tests this ship.
- [ ] **AC-7:** PR squash-merge title = `feat(bts-245-linear-query-substrate-manifests): linear-query.sh provider substrate manifests`.
- [ ] **AC-8:** Live-AC — next `/recall` after merge surfaces `Manifest coverage: 118 / 118 (allowlist), drift: 0`. [linear-query.sh](<http://linear-query.sh>) is 100% covered (16/16 cmd\_\*).

## Affected Files

| File | Change |
| -- | -- |
| `.ccanvil/scripts/linear-query.sh` | Modified — 16 `# @manifest` blocks + inline markers added |
| `.ccanvil/manifest-allowlist.txt` | Modified — +16 entries with section headers |

## Dependencies

* **Requires:** BTS-239 (substrate), BTS-243/244 (mega-script pattern reference).
* **Blocked by:** none.

## Out of Scope

* Function-body changes. Coverage-only.
* New tests.
* Other small mega-scripts (manifest-check, permissions-audit, operations, context-budget) — Session 7.

## Implementation Notes

* *In-scope cmd\_* (16):\* Batch 1 viewer+listings — cmd_viewer, cmd_list_issues, cmd_list_states, cmd_list_labels, cmd_list_teams. Batch 2 issue+project+doc listings — cmd_get_issue, cmd_list_projects, cmd_list_documents. Batch 3 issue mutations — cmd_create_relation, cmd_save_issue. Batch 4 document core — cmd_resolve_document_id, cmd_get_document, cmd_document_updated_at. Batch 5 document mutations — cmd_save_document, cmd_trash_document, cmd_document_history.
* **Format:** Same as BTS-244. Per-batch validate-fix-commit. Drift-guard catches phantoms.
* **GraphQL semantics in manifest:** Capture each wrapper's GraphQL operation name, field set, mutation/query, and rate-limit/error semantics in `purpose:` and `failure-mode:` lines.
* **Common dependencies:** \_post_graphql, \_require_api_key, \_load_env_if_needed, \_die.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
