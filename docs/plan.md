# Implementation Plan: Clean Init & Broadcast Commits

> Feature: clean-init-commits
> Created: 1776386558
> Spec hash: 7af0161c
> Based on: docs/spec.md

## Objective

Auto-commit hub-owned registry mutations during `register`, `migrate_registry`, and `broadcast`, and make the bootstrap commit in `cmd_broadcast` tolerant of gitignored lockfiles — so `/init` and `broadcast` leave the hub in a clean state.

## Sequence

### Step 1: Helper — commit_hub_file (AC-1, AC-2, AC-3, AC-4, AC-8)
- **Test:** `commit_hub_file <hub> <relpath> <message>`:
  - returns 0 when the file exists, is modified, and commit succeeds
  - returns 0 (no-op) when the file is unchanged (diff --quiet = 0)
  - returns 0 (no-op) when `$hub` is not a git repo
  - returns 0 with WARNING on stderr when commit fails (e.g., pre-commit hook blocks)
  - commits ONLY the specified file (no `-A`)
- **Implement:** Add `commit_hub_file()` helper near `safe_lock_mv`. Uses `ALLOW_MAIN=1` to bypass protect-main hook. Uses `git -c commit.gpgsign=false` (per workflow rule, only because these are automated sync-lifecycle commits).
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh`
- **Verify:** Helper tests pass.

### Step 2: cmd_register auto-commits registry (AC-1, AC-2, AC-6)
- **Test:** After `register`, hub `.ccanvil/registry.json` is committed. Hub working tree has no `registry.json` in `git status --porcelain`. Repeat register (no-op) makes no new commit.
- **Implement:** Call `commit_hub_file "$hub_root" ".ccanvil/registry.json" "chore(registry): register $node_name [$node_uuid]"` at the end of `cmd_register`.
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh`
- **Verify:** Register tests still pass. New test covers hub is clean.

### Step 3: migrate_registry auto-commits (AC-3, AC-7)
- **Test:** After a broadcast that migrated path-keyed entries, hub's registry.json is committed.
- **Implement:** In `cmd_broadcast` prelude (right after the `migrate_registry` call), invoke `commit_hub_file "$hub_root" ".ccanvil/registry.json" "chore(registry): migrate to UUID keys"`.
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh`
- **Verify:** Tests pass.

### Step 4: Broadcast batch last_synced auto-commit (AC-4, AC-7)
- **Test:** After a clean broadcast run, hub has `chore(registry): record broadcast sync` commit. Hub tree clean post-broadcast.
- **Implement:** After the batch `last_synced` update loop in `cmd_broadcast`, call `commit_hub_file`.
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh`
- **Verify:** Tests pass.

### Step 5: Bootstrap commit tolerates gitignored lockfile (AC-5)
- **Test:** When a node gitignores `.ccanvil/ccanvil.lock`, bootstrap commits only the sync script, no error. Broadcast proceeds to sync the node normally. When lockfile is tracked, both files commit together.
- **Implement:** In `cmd_broadcast` bootstrap commit block: for each candidate file, run `git check-ignore -q` in the node. If ignored, skip that file in `git add`. If at least one file remains, commit; if all ignored, skip the commit.
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh`
- **Verify:** Tests pass.

### Step 6: Regression sweep (AC-9)
- **Test:** `bats hub/tests/` — all green.
- **Implement:** Fix any regressions.
- **Files:** Any
- **Verify:** 491+ tests passing.

### Step 7: Doc update
- **Implement:** One-line note in `.ccanvil/guide/command-reference.md` under "Registry & Node Identity" mentioning auto-commit behavior.
- **Files:** `.ccanvil/guide/command-reference.md`
- **Verify:** `docs-check.sh validate` passes.

## Risks

- **protect-main.sh blocks auto-commit:** The hub's main branch has a PreToolUse hook blocking direct commits. Using `ALLOW_MAIN=1` on each `git commit` subshell invocation is the intended escape hatch (documented). If the user has further guard hooks, they could still block. Mitigate: AC-8 (failure tolerance) catches this and prints a warning.
- **Multiple registry commits per broadcast:** migrate + batch-update could produce two commits per broadcast. Acceptable — each has a distinct purpose. Could be collapsed later if noisy.
- **`git -c commit.gpgsign=false` clashes with user preference:** Global CLAUDE.md says "Never skip hooks / bypass signing unless explicitly requested." These auto-commits are explicitly requested by this spec. Marking in commit body is the safety net.

## Definition of Done

- [ ] All 9 acceptance criteria pass
- [ ] All existing tests still pass
- [ ] Hub working tree clean after any `register` or `broadcast` invocation
- [ ] Code reviewed (run /review)
