# Implementation Plan: Docs Lifecycle Linking

> Created: 2026-03-22
> Based on: docs/spec.md

## Objective

Add deterministic linking between spec.md, plan.md, and checkpoint.md via metadata + hash chain, validated by `docs-check.sh` and surfaced by `/catchup`.

## Sequence

### Step 1: Metadata extraction — `docs-check.sh status`
- **Test:** Given spec.md with `> Feature: my-feature` and `> Status: In Progress`, `status` outputs JSON with `feature_id: "my-feature"` and `status: "In Progress"`. Same for plan.md (with `spec_hash`) and checkpoint.md (with `plan_hash`).
- **Implement:** `scripts/docs-check.sh` with `cmd_status` — parse blockquote metadata lines from each doc using grep/awk. Output JSON object with per-document entries.
- **Files:** `scripts/docs-check.sh` (new), `tests/docs-check.bats` (new)
- **Verify:** `bats tests/docs-check.bats`
- **ACs:** AC-1

### Step 2: Content hashing
- **Test:** Given a spec.md with metadata header and body content, the computed `content_hash` is the sha256 (first 8 chars) of everything below the metadata blockquote. Changing metadata doesn't change the hash; changing body does.
- **Implement:** `cmd_hash` subcommand — strips blockquote lines from top, hashes remainder.
- **Files:** `scripts/docs-check.sh`, `tests/docs-check.bats`
- **Verify:** `bats tests/docs-check.bats`
- **ACs:** Supports AC-2 through AC-5

### Step 3: Validate — aligned and stale cases
- **Test:** (a) All three docs share feature_id, plan's spec_hash matches spec's current hash, checkpoint's plan_hash matches plan's current hash → `aligned`. (b) Modify spec body → `stale-plan`. (c) Modify plan body → `stale-checkpoint`. (d) Different feature_ids → `mismatched`.
- **Implement:** `cmd_validate` — calls `cmd_status` internally, compares stored hashes against computed hashes, checks feature_id agreement.
- **Files:** `scripts/docs-check.sh`, `tests/docs-check.bats`
- **Verify:** `bats tests/docs-check.bats`
- **ACs:** AC-2, AC-3, AC-4, AC-5

### Step 4: Validate — missing docs and unlinked metadata
- **Test:** (a) Only spec.md exists → reports plan and checkpoint missing, no error. (b) Doc exists but has no lifecycle metadata → `unlinked`. (c) All docs missing → reports all missing.
- **Implement:** Extend `cmd_validate` with existence checks and `unlinked` status.
- **Files:** `scripts/docs-check.sh`, `tests/docs-check.bats`
- **Verify:** `bats tests/docs-check.bats`
- **ACs:** AC-6

### Step 5: Recommend — state machine
- **Test:** (a) spec exists, no plan → `{"next_action": "Run /plan", "reason": "..."}`. (b) spec+plan linked, no checkpoint → `{"next_action": "Ready to build", ...}`. (c) stale-plan → `{"next_action": "Re-run /plan", ...}`. (d) all aligned with checkpoint → `{"next_action": "/clear and /catchup to resume", ...}`. (e) No docs → `{"next_action": "Describe a feature", ...}`.
- **Implement:** `cmd_recommend` — calls `cmd_validate`, maps validation result to next action via case statement.
- **Files:** `scripts/docs-check.sh`, `tests/docs-check.bats`
- **Verify:** `bats tests/docs-check.bats`
- **ACs:** AC-12

### Step 6: Update templates with metadata fields
- **Test:** Verify templates contain the expected metadata field placeholders (grep for `Feature:`, `Spec hash:`, `Plan hash:` in template files).
- **Implement:** Add `> Feature: [feature-id]` to all three templates. Add `> Spec hash: [hash]` to plan template. Add `> Plan hash: [hash]` to checkpoint template. Add pre-checkpoint reminder comment to checkpoint template.
- **Files:** `docs/templates/spec.md`, `docs/templates/plan.md`, `docs/templates/checkpoint.md`
- **Verify:** `bats tests/docs-check.bats` (template grep tests)
- **ACs:** AC-7

### Step 7: Update spec-writer, /plan, and workflow rule
- **Test:** Read modified files, verify they contain instructions to populate metadata fields.
- **Implement:** (a) spec-writer.md: instruction to derive feature_id as kebab-case slug from feature name, write `> Feature: slug` in metadata. (b) plan.md command: instruction to read spec's feature_id and compute spec content hash, write both to plan metadata. (c) workflow.md: instruction for checkpoint writing to read plan's feature_id and compute plan content hash, write both to checkpoint metadata. Add "plan before checkpoint" convention.
- **Files:** `.claude/agents/spec-writer.md`, `.claude/commands/plan.md`, `.claude/rules/workflow.md`
- **Verify:** Manual review — these are prompt changes, not code.
- **ACs:** AC-8, AC-9, AC-10

### Step 8: Update /catchup to run docs-check first
- **Test:** Read modified catchup.md, verify it calls `docs-check.sh validate` and `docs-check.sh recommend` before reading documents.
- **Implement:** Add steps 0a and 0b to catchup.md: run `docs-check.sh validate` and `docs-check.sh recommend`, report results before proceeding to existing steps.
- **Files:** `.claude/commands/catchup.md`
- **Verify:** Manual review — prompt change.
- **ACs:** AC-11, AC-13

### Step 9: Integration — README, GUIDE, lockfile
- **Test:** Run `manifest-check.sh check README.md` — docs-check.sh should appear as verified, zero missing.
- **Implement:** Add `docs-check.sh` to README scripts manifest table. Add lifecycle linking to GUIDE.md command reference and appendix. Re-init manifest lockfile.
- **Files:** `README.md`, `GUIDE.md`, `.claude/manifest.lock`
- **Verify:** `bats tests/` (full suite), `manifest-check.sh check README.md` (clean)
- **ACs:** All — integration verification

## Risks

- **Metadata parsing fragility:** Blockquote lines (`> Key: value`) could be confused with quoted content in the document body. Mitigation: only parse consecutive `>` lines from the very top of the file (stop at first non-blockquote line after the heading).
- **Hash instability from whitespace:** Trailing whitespace or line-ending differences could change hashes. Mitigation: normalize content before hashing (strip trailing whitespace, ensure final newline).
- **Heading line before blockquote:** The docs start with `# Feature Name` then `> metadata`. The parser needs to skip the heading and parse the blockquote block. Define clearly: metadata = consecutive `>` lines after the first `#` heading.

## Definition of Done

- [ ] All acceptance criteria from spec pass
- [ ] All existing tests still pass (106 + new docs-check tests)
- [ ] `docs-check.sh` follows same pattern as `manifest-check.sh`
- [ ] `/catchup` surfaces lifecycle state before document content
- [ ] Templates, agents, and commands updated with metadata instructions
