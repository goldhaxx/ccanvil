# Implementation Plan: Spec Metadata Format Resilience

> Feature: spec-metadata-format
> Created: 1776276101
> Spec hash: tbd

## Objective

Extend `parse_metadata()` to handle both blockquote and YAML frontmatter formats. Fix `recommend` guidance to align with `activate` behavior.

## Sequence

### Step 1: Tests for YAML frontmatter parsing (AC-2, AC-7)

Add tests to `hub/tests/docs-check.bats` in a new section:

- `parse_metadata` via `status` subcommand on a spec with YAML frontmatter returns correct feature_id, status, created
- `parse_metadata` on a file with no recognizable metadata still returns `{}`
- `parse_metadata` on blockquote format still works (regression guard — existing tests cover this but add an explicit one)

### Step 2: Extend `parse_metadata()` (AC-1, AC-2)

In `docs-check.sh` lines 81-150, add YAML frontmatter detection:

- If line 1 is `---`, enter YAML mode: read until closing `---`, parse `key: value` lines
- Map keys: `feature`/`Feature` → `feature_id`, `created`/`Created` → `created`, `status`/`Status` → `status`, etc.
- If line 1 is NOT `---`, fall through to existing blockquote logic
- No new dependencies (no `yq`) — use `sed`/bash string manipulation

### Step 3: Tests for list-specs with mixed formats (AC-3)

Add tests to `hub/tests/feature-lifecycle.bats`:

- `list-specs` finds a YAML-frontmatter spec alongside a blockquote spec
- Both appear in the JSON array with correct metadata

### Step 4: Tests for activate/complete with YAML frontmatter (AC-4, AC-5)

Add tests to `hub/tests/feature-lifecycle.bats`:

- `activate` works on a YAML-frontmatter spec (creates branch, copies to spec.md)
- `complete` works on a YAML-frontmatter spec (updates status)

### Step 5: Fix recommend guidance (AC-8)

In `docs-check.sh` line 398, change:
- `"Mark a spec as Ready, then activate it"` → `"Activate a spec: docs-check.sh activate <id>"`
- This aligns with actual `activate` behavior (no status gate)

Update test in `hub/tests/feature-lifecycle.bats` line 537 and `hub/tests/docs-check.bats` line 473+ to match new wording.

### Step 6: Full suite verification (AC-9)

Run `bats hub/tests/` — all 444+ tests must pass.

## Risk

- YAML parsing in pure bash is fragile for complex YAML. Scope is intentionally narrow: only flat `key: value` pairs between `---` delimiters. Nested YAML, arrays, and multi-line values are out of scope.
