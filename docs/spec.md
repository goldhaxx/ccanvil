# Feature: Safe init with conflict-aware merge planning

> Feature: safe-init
> Created: 1775609444
> Status: In Progress

## Summary

Replace the blind-copy step in `/init` with an intelligent preflight that scans source (hub preset) and destination (target project), detects file conflicts, recommends per-file resolution strategies, and presents a merge plan for user review. When no conflicts exist, init proceeds without interruption.

## Job To Be Done

**When** I run `/init` in a project that already has a CLAUDE.md, custom rules, or other files that overlap with the hub preset,
**I want** an automatic analysis that classifies each file and recommends merge/skip/overwrite,
**So that** I never lose existing project content and can review exactly what will change before it happens.

## Acceptance Criteria

### Preflight scan

- [ ] **AC-1:** `ccanvil-sync.sh init-preflight <hub-path>` scans all tracked patterns in both the hub preset and the target project directory. Outputs a JSON plan with per-file entries.
- [ ] **AC-2:** Each file entry includes: `file`, `source` (hub-only | local-only | both), `recommended_action` (copy | skip | section-merge | review), and `reason` (human-readable explanation).
- [ ] **AC-3:** When `source` is `both`, the preflight compares hashes. If identical → `recommended_action: skip` (already matches). If different → classifies based on file type:
  - Files with section-merge delimiters (`<!-- HUB-MANAGED-START -->`) → `section-merge`
  - All other files → `review` (requires user judgment)
- [ ] **AC-4:** When `source` is `hub-only` → `recommended_action: copy` (no conflict).
- [ ] **AC-5:** When `source` is `local-only` → `recommended_action: skip` (preserve local, not a hub file).

### Plan output and approval

- [ ] **AC-6:** The preflight outputs a summary line: `Conflicts: N files require review | Auto: M files can proceed`. If conflicts is 0, outputs `No conflicts detected — ready to proceed.`
- [ ] **AC-7:** The `/init` skill calls `init-preflight` before any file operations. If conflicts > 0, it presents the plan to the user in a readable table (file, action, reason) and asks for approval before proceeding.
- [ ] **AC-8:** The user can approve the plan as-is, deny (abort), or edit individual file actions (e.g., change `review` to `copy` or `skip`).

### Execution

- [ ] **AC-9:** `ccanvil-sync.sh init-apply <hub-path> <plan-json>` executes the approved plan. For each file:
  - `copy`: copies from hub preset to target
  - `skip`: does nothing (preserves local file)
  - `section-merge`: runs `cmd_section_merge` using hub file as source and local file as target
  - `overwrite`: copies from hub preset, replacing local (only when user explicitly chose this)
- [ ] **AC-10:** `init-apply` outputs a results summary: files copied, skipped, merged, with any errors.

### No-conflict fast path

- [ ] **AC-11:** When preflight finds zero conflicts (all files are hub-only or identical), the `/init` skill proceeds directly to `init-apply` without pausing for user review.

### Backward compatibility

- [ ] **AC-12:** Running `/init` in an empty project (no pre-existing files) behaves identically to today — all files are `hub-only` → `copy`, zero conflicts, no pause.
- [ ] **AC-13:** `cmd_init` (lockfile generation) is unchanged — it runs after `init-apply` and records the post-apply state.

### Tests

- [ ] **AC-14:** All existing tests pass (369+).
- [ ] **AC-15:** New tests cover: preflight with no conflicts, preflight with hash-identical files, preflight with section-merge files, preflight with conflicting files, init-apply copy/skip/merge actions.

## Affected Files

| File | Change |
|------|--------|
| `preset/.ccanvil/scripts/ccanvil-sync.sh` | Add `cmd_init_preflight` and `cmd_init_apply` |
| `hub/tests/ccanvil-sync.bats` | New tests for preflight and apply |
| `global-commands/init.md` | Update to call preflight → review → apply flow |

## Dependencies

- **Requires:** Existing `cmd_section_merge`, `scan_hub_files`, `scan_tracked_files`, `file_hash` helpers

## Out of Scope

- Preflight for pull/push operations (those already have their own plan mechanisms)
- Interactive TUI for plan editing (Claude presents the plan; user responds in natural language)
- Backup/rollback of overwritten files (git provides this via the initial commit)

## Implementation Notes

- `init-preflight` reuses `scan_hub_files` and `scan_tracked_files` with hash comparison — same primitives as `cmd_init`
- Section-merge detection: check if the local file contains `<!-- HUB-MANAGED-START -->` OR if the hub file does (the delimiter is what makes merge possible)
- The plan JSON is passed from preflight → Claude review → apply. Claude may modify actions based on user feedback before passing to apply.
- GitHub template files (README.md, CONTRIBUTING.md, etc.) should also be scanned — they're currently copied outside the tracked pattern system. Consider adding them to the preflight scan explicitly.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
