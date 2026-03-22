# Feature: Docs Lifecycle Linking

> Created: 2026-03-22
> Status: In Progress

## Summary

Add deterministic linking between spec.md, plan.md, and checkpoint.md so that staleness is machine-detectable. A `docs-check.sh` script validates the chain; `/catchup` runs it automatically and reports drift before reading content.

## Job To Be Done

**When** I run `/catchup` after a `/clear`,
**I want to** immediately know if my spec, plan, or checkpoint are stale or mismatched,
**So that** I don't waste a session working from outdated context.

## Acceptance Criteria

- [ ] **AC-1:** `docs-check.sh status` reads metadata from spec.md, plan.md, and checkpoint.md and outputs JSON with each document's feature_id, stored hashes, and computed current hashes.
- [ ] **AC-2:** `docs-check.sh validate` reports `aligned` when all three docs share the same feature_id and stored hashes match current hashes.
- [ ] **AC-3:** `docs-check.sh validate` reports `stale-plan` when spec.md's current content hash differs from the spec_hash stored in plan.md (spec evolved since plan was written).
- [ ] **AC-4:** `docs-check.sh validate` reports `stale-checkpoint` when plan.md's current content hash differs from the plan_hash stored in checkpoint.md (plan evolved since checkpoint was written).
- [ ] **AC-5:** `docs-check.sh validate` reports `mismatched` when feature_ids don't match across documents (different features).
- [ ] **AC-6:** `docs-check.sh validate` handles missing documents gracefully — reports which are missing, doesn't error.
- [ ] **AC-7:** Templates (spec.md, plan.md, checkpoint.md) include metadata fields: `feature_id`, `spec_hash` (plan only), `plan_hash` (checkpoint only).
- [ ] **AC-8:** The spec-writer agent populates `feature_id` as a kebab-case slug derived from the feature name.
- [ ] **AC-9:** The `/plan` command populates `feature_id` (from spec) and `spec_hash` (computed from current spec content).
- [ ] **AC-10:** Checkpoint writing populates `feature_id` (from plan) and `plan_hash` (computed from current plan content).
- [ ] **AC-11:** The `/catchup` command runs `docs-check.sh validate` first and reports any staleness/mismatches before reading document content.
- [ ] **AC-12:** `docs-check.sh recommend` outputs a JSON recommendation (next_action + reason) based on a document state machine — e.g., spec exists but no plan → "Run /plan"; plan stale → "Re-run /plan"; all linked → "Ready to build".
- [ ] **AC-13:** `/catchup` displays the recommendation from `docs-check.sh recommend` before document content, so the user sees the optimal next step immediately.

## Affected Files

| File | Change |
|------|--------|
| `scripts/docs-check.sh` | New — lifecycle validation script |
| `tests/docs-check.bats` | New — tests for the script |
| `docs/templates/spec.md` | Modified — add `feature_id` metadata field |
| `docs/templates/plan.md` | Modified — add `feature_id` and `spec_hash` metadata fields |
| `docs/templates/checkpoint.md` | Modified — add `feature_id` and `plan_hash` metadata fields |
| `.claude/agents/spec-writer.md` | Modified — populate feature_id |
| `.claude/commands/plan.md` | Modified — populate feature_id + spec_hash |
| `.claude/commands/catchup.md` | Modified — run docs-check first |
| `.claude/rules/workflow.md` | Modified — checkpoint writing populates feature_id + plan_hash; add "plan before checkpoint" convention |
| `docs/templates/checkpoint.md` | Modified — add pre-checkpoint reminder comment |
| `README.md` | Modified — add docs-check.sh to scripts manifest |
| `GUIDE.md` | Modified — document lifecycle linking in command reference |

## Dependencies

- **Requires:** Metadata format convention (blockquote `>` lines at top of each doc)
- **Blocked by:** Nothing

## Out of Scope

- Auto-updating stale docs (the script reports, humans decide)
- Version history of specs (git handles this)
- Linking to git commits or branches (lifecycle is doc-to-doc only)
- Hooks to enforce linking (script + command integration is sufficient)

## Implementation Notes

- **Metadata format:** Use the existing `>` blockquote header. Add fields like `> Feature: my-feature-slug` and `> Spec hash: abc123`. This keeps metadata human-readable and avoids introducing YAML frontmatter to working docs.
- **Hash computation:** Hash the document content *below* the blockquote metadata section. This way, updating the `Status:` field in spec.md doesn't invalidate the plan's spec_hash — only substantive content changes do.
- **Hash algorithm:** sha256, truncated to first 8 chars for readability in metadata lines.
- **Missing metadata:** If a doc exists but has no lifecycle metadata, `docs-check.sh` reports it as `unlinked` (not an error — supports pre-existing docs and gradual adoption).
- **Pattern:** Same as `manifest-check.sh` — bash script with subcommands, JSON output, tested with bats.
