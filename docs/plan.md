# Implementation Plan: Downstream Sync Automation

> Feature: downstream-sync-auto
> Created: 1776135305

## Steps

### 1. Add `broadcast` subcommand skeleton + empty registry test
- Add `cmd_broadcast()` function and case statement entry
- Function detects hub root (current dir if registry exists, or via lockfile)
- Reads registry.json, exits 0 with "No registered nodes" if empty
- Test: broadcast with empty registry → exit 0, correct message (AC-12)

### 2. Node iteration with pre-check gating
- Iterate over `jq '.nodes | keys[]'` from registry
- For each node: check path exists (AC-8), cd into subshell, run `pre-check`
- Skip nodes that fail pre-check with reason (AC-2)
- Track counts: synced, skipped (with reasons), unreachable
- Tests: unreachable node path, dirty node tree → skipped

### 3. Pull workflow per node (plan → auto → section-merge → finalize)
- In the per-node subshell: run `pull-plan`, parse JSON
- Run `pull-auto` for auto-update actions
- For section-merge actions: run `pull-apply <file> section-merge`
- Run `pull-finalize`
- Collect conflict entries per node (AC-3)
- Tests: hub change auto-updates in node, section-merge preserves node content

### 4. `--dry-run` flag
- Thread `--dry-run` through to `pull-auto`, `pull-apply`, `pull-finalize`
- Broadcast itself also suppresses registry updates in dry-run mode
- Test: dry-run produces output but no file changes (AC-4)

### 5. Registry `last_synced` tracking
- After successful broadcast to a node, update registry.json with `last_synced` (epoch) and `last_synced_version` (hub HEAD short hash) (AC-5)
- Update `cmd_registry()` to display these fields, showing "never" for missing (AC-6)
- Tests: registry fields populated after broadcast, "never" for unsynced nodes

### 6. Broadcast summary report
- At end of broadcast, print summary: synced count, skipped count + reasons, conflicts pending per node (AC-9)
- Test: verify summary format matches spec

### 7. Guide and command-reference updates
- Update `.ccanvil/guide/sync.md` with broadcast flow
- Update `.ccanvil/guide/command-reference.md` with broadcast entry
- Verify all tests pass (AC-11)
