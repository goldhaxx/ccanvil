# Plan: Flatten Hub Architecture

> Feature: flatten-hub-architecture
> Created: 1776058400

## Phase 1: Physical migration
1. Delete `.ccanvil` symlink, move `preset/.ccanvil/` → `.ccanvil/`
2. Reconcile `preset/.claude/` into `.claude/` (preset is canonical; overlay hub-only files)
3. Move `hub/specs/` → `docs/specs/` (real dir, replaces symlink)
4. Merge CLAUDE.md files
5. Delete `preset/`

## Phase 2: Script updates
6. Delete `hub_dist_root` from ccanvil-sync.sh, update 6 call sites
7. Update comments in ccanvil-sync.sh, docs-check.sh, context-budget.sh

## Phase 3: Documentation updates
8. Rewrite CLAUDE.md Architecture section
9. Update `.ccanvil/guide/` references (7 files, 11 refs)
10. Update test comments (2 files, 2 refs)

## Phase 4: Verify
11. Run full test suite (406+ tests)
12. Verify downstream lockfile compatibility
