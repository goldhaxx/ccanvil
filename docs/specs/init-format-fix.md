# Feature: Init Format Fix

> Feature: init-format-fix
> Created: 1776103445
> Status: Complete

## Summary

Fix `init-apply` to accept the full preflight output object directly. Currently `init-preflight` outputs `{plan:[], summary:{}}` but `init-apply` expects a bare JSON array, forcing callers to manually extract `.plan` with jq. This breaks the init flow for users who save preflight output directly to the plan file.

## Job To Be Done

**When** running `/init` on a new project,
**I want to** save the preflight output directly as the plan file and pass it to init-apply,
**So that** the init flow works without manual jq extraction steps.

## Acceptance Criteria

Each criterion is independently testable. Binary pass/fail.

- [ ] **AC-1:** `init-apply` accepts the full preflight output `{plan:[], summary:{}}` and processes all entries correctly
- [ ] **AC-2:** `init-apply` still accepts a bare JSON array `[{...}]` for backwards compatibility
- [ ] **AC-3:** Tests pass the full preflight output directly to init-apply (no manual `.plan` extraction)
- [ ] **AC-4:** Error: when plan file contains invalid JSON, init-apply exits with a clear error message
- [ ] **AC-5:** The full init-preflight → init-apply round-trip works on an empty project without intermediate jq steps

## Affected Files

| File | Change |
|------|--------|
| `.ccanvil/scripts/ccanvil-sync.sh` | Modified — init-apply auto-detects format |
| `hub/tests/ccanvil-sync.bats` | Modified — remove manual `.plan` extraction from tests |

## Dependencies

- **Requires:** None
- **Blocked by:** None

## Out of Scope

- Changes to init-preflight output format (it's correct as-is)
- The pre-push hook template issue (confirmed not a bug — file exists)
- Changes to global-commands/init.md (will be updated in BTS-69)

## Implementation Notes

- Add format detection at the top of `cmd_init_apply`: check if root is object with `.plan` key, extract it; otherwise treat as bare array
- Use `jq 'if type == "array" then . else .plan end'` pattern for auto-detection
- Update all 5 test cases that manually extract `.plan` to pass full preflight output directly
