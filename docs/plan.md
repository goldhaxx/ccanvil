# Implementation Plan: Scaffold-Wide Epoch Timestamps

> Feature: epoch-timestamps
> Created: 1742860800
> Spec hash: b14cfc0f
> Based on: docs/spec.md

## Objective

Convert `scaffold-sync.sh` and `manifest-check.sh` from date strings to Unix epoch seconds for all internal timestamp fields.

## Sequence

### Step 1: scaffold-sync.sh — timestamp() helper
- **Test:** Run existing scaffold-sync tests to confirm green baseline. Then verify `timestamp()` output is an integer.
- **Implement:** Change `date -u +"%Y-%m-%dT%H:%M:%SZ"` to `date +%s` in `timestamp()`.
- **Files:** `scripts/scaffold-sync.sh`
- **Verify:** `bats tests/scaffold-sync.bats`
- **ACs:** AC-1, AC-2, AC-6

### Step 2: manifest-check.sh — cmd_init epoch
- **Test:** Run existing manifest-check tests to confirm green baseline. Then add a test asserting the `verified` field is numeric (not a date string).
- **Implement:** In `cmd_init`, change `today="$(date +%Y-%m-%d)"` to `now="$(date +%s)"`, update variable references.
- **Files:** `scripts/manifest-check.sh`, `tests/manifest-check.bats`
- **Verify:** `bats tests/manifest-check.bats`
- **ACs:** AC-3, AC-7

### Step 3: manifest-check.sh — cmd_verify epoch
- **Test:** Add a test asserting the `verified` field after verify is numeric.
- **Implement:** In `cmd_verify`, same change: `today` → `now`, `date +%Y-%m-%d` → `date +%s`.
- **Files:** `scripts/manifest-check.sh`, `tests/manifest-check.bats`
- **Verify:** `bats tests/manifest-check.bats`
- **ACs:** AC-4, AC-7

### Step 4: Re-init lockfile + full suite verification
- **Test:** Run `manifest-check.sh init README.md`, then `manifest-check.sh check README.md` — all entries verified, zero issues.
- **Implement:** Re-init lockfile. Run full test suite.
- **Files:** `.claude/manifest.lock`
- **Verify:** `bats tests/` (full suite), `manifest-check.sh check README.md`
- **ACs:** All — integration verification

## Risks

- **Test format assertions:** If any test asserts `verified =~ /^\d{4}-\d{2}-\d{2}$/`, it will break. Mitigation: grep tests for date patterns before changing.
- **Downstream lockfile parsing:** If downstream projects (fucina) parse `synced_at` or `verified` expecting a date string, they'll break. Mitigation: document the format change; downstream projects need a `/scaffold-pull` to get the updated scripts.

## Definition of Done

- [ ] All acceptance criteria from spec pass
- [ ] All existing tests still pass (142 + any new)
- [ ] `fetch-license.sh` still uses `date +%Y` (not converted)
- [ ] Lockfiles regenerated with epoch format
