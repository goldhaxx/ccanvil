# Implementation Plan: Stable Node UUIDs for Registry

> Feature: node-uuid-registry
> Created: 1776383140
> Spec hash: f2f788be
> Based on: docs/spec.md

## Objective

Replace path-keyed registry with UUID-keyed registry, generating stable UUIDs at node init and storing them in both `.ccanvil/ccanvil.lock` and `.claude/ccanvil.json`, with portable paths and migration from the legacy schema.

## Sequence

### Step 1: UUID generation + dual storage in init (AC-1, AC-10)
- **Test:** `init` writes a lowercase v4 UUID to both `.ccanvil/ccanvil.lock.node_uuid` and `.claude/ccanvil.json.node_uuid`. Re-running `init` preserves the existing UUID. Malformed UUID in `.claude/ccanvil.json` causes init to fail with clear error.
- **Implement:** Add `generate_uuid()` helper (uses `uuidgen` with `| tr '[:upper:]' '[:lower:]'` on macOS; falls back to Python `uuid.uuid4()` if `uuidgen` missing). Add `validate_uuid()` (regex: `^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`). Add `get_or_create_node_uuid()` helper: read from `.claude/ccanvil.json`, validate, return; else generate new, write to both files. Call it in `cmd_init` after lockfile is written.
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh`, `hub/tests/node-uuid-registry.bats` (new)
- **Verify:** Tests pass. `.claude/ccanvil.json` and `.ccanvil/ccanvil.lock` both contain same UUID.

### Step 2: UUID recovery on lockfile regen (AC-2)
- **Test:** Given `.claude/ccanvil.json` has a UUID and `.ccanvil/ccanvil.lock` is deleted, re-running `init` recovers the UUID from ccanvil.json into the new lockfile — does not generate a new one.
- **Implement:** `get_or_create_node_uuid()` already covers this if Step 1 reads from `.claude/ccanvil.json` first. Verify ordering: check ccanvil.json → validate → use; only generate if missing from both.
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh` (refine if needed)
- **Verify:** Test passes.

### Step 3: Path normalization helpers (AC-3 prep)
- **Test:** `normalize_path "/Users/zach/projects/taxes"` returns `~/projects/taxes`. `expand_path "~/projects/taxes"` returns `/Users/zach/projects/taxes`.
- **Implement:** Add `normalize_path()` and `expand_path()` helpers near existing `timestamp()`/`file_hash()` helpers. Use `${path/#$HOME/~}` and `${path/#\~/$HOME}` — same pattern as line 243.
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh`
- **Verify:** Unit tests pass.

### Step 4: UUID-keyed register command (AC-3, AC-4)
- **Test:** `register` writes UUID-keyed entry with `name`, `path` (~-form), `registered_at`. Running `register` again from the same node updates the existing entry — no duplicate. Running `register` after moving the directory updates the `path` field to the new location.
- **Implement:** Modify `cmd_register()` (lines 1756–1786): read node UUID via `get_or_create_node_uuid()`, normalize path, key by UUID instead of path. Use `jq '.nodes[$u] = {...}'` where `$u` is UUID.
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh`
- **Verify:** Tests pass. Existing registry tests still pass.

### Step 5: registry-list command includes UUID (AC-9)
- **Test:** `ccanvil-sync.sh registry` output includes a UUID column/field for each node.
- **Implement:** Modify `cmd_registry()` to include UUID in JSON output. If text output exists, add UUID column.
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh`
- **Verify:** Tests pass.

### Step 6: Broadcast iterates by UUID with path expansion (AC-5)
- **Test:** `broadcast` iterates registry by UUID, expands `~` paths at runtime, validates path exists, syncs node.
- **Implement:** Modify `cmd_broadcast()` iteration: `jq '.nodes | keys[]'` returns UUIDs; read `.nodes[$uuid].path`; expand via `expand_path()`; validate `[[ -d "$resolved_path" ]]` before sync. Also update the deferred registry update (inside cmd_broadcast) to key by UUID.
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh`
- **Verify:** Tests pass. Multi-node broadcast test still works.

### Step 7: Broadcast stale path detection (AC-6)
- **Test:** When a registry UUID's path doesn't exist, broadcast prints `STALE: <name> (<uuid>) at <path>` and skips. Other nodes continue to sync.
- **Implement:** In `cmd_broadcast()` iteration, when path validation fails, print stale message with UUID and name, increment `skipped`, add to `skip_reasons`, `continue`.
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh`
- **Verify:** Tests pass.

### Step 8: Migration logic in broadcast (AC-7, AC-8)
- **Test:** Given a legacy path-keyed registry, `broadcast` detects entries with path-like keys (contain `/`) and migrates them: read node's UUID (or trigger generation), create UUID-keyed entry with path/name/registered_at preserved, delete old path-keyed entry. Running `broadcast` again on already-migrated registry is a no-op.
- **Implement:** Add `migrate_registry()` function called in `cmd_broadcast` prelude. For each key: if it starts with `/` or `~`, treat as legacy path. Resolve path, cd into it, run `get_or_create_node_uuid()` (triggers generation in the node if absent). Rewrite entry under UUID key with `path` normalized. Delete old path key. Idempotent because UUID-keyed entries skip the path-detection branch.
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh`
- **Verify:** Migration test passes. Idempotency test passes.

### Step 9: Regression sweep (AC-11)
- **Test:** Full `bats hub/tests/` suite passes.
- **Implement:** Fix any regressions in existing tests (ccanvil-sync, operations, tech-stack-distribution, etc.) caused by registry schema changes.
- **Files:** Any
- **Verify:** 472+ tests passing.

### Step 10: Documentation updates
- **Implement:** Update `.ccanvil/guide/command-reference.md` (registry schema, new UUID behavior). Add a one-line note to `CLAUDE.md` hub section if any user-facing command changes.
- **Files:** `.ccanvil/guide/command-reference.md`, `CLAUDE.md` (if needed)
- **Verify:** `docs-check.sh validate` passes.

## Risks

- **`uuidgen` availability:** Always present on macOS; Linux may need `util-linux` or fallback. Mitigate with a Python fallback (`python3 -c 'import uuid; print(uuid.uuid4())'`) — Python3 is universally available where bats/jq are.
- **Migration during an active broadcast:** If migration fails mid-flight (e.g., one node unreachable during UUID generation), registry could end up partially migrated. Mitigate by treating migration as per-node — each entry migrates independently; partial success leaves the rest path-keyed for next broadcast.
- **Registry committed to hub git:** The hub repo already tracks `.ccanvil/registry.json`. Switching to portable paths (`~/...`) removes username leakage. Existing git history still has paths, but that's acceptable — new commits won't.
- **Downstream nodes with older sync scripts:** After this ships, a downstream on the old sync script won't know about `node_uuid`. First sync will bootstrap the new script via pre-check, then migration runs on next broadcast. Backward-compatible because migration checks for both key shapes.

## Definition of Done

- [ ] All 11 acceptance criteria from spec pass
- [ ] All existing tests still pass (regression sweep)
- [ ] Migration tested with a fixture resembling the current real registry (4 path-keyed entries)
- [ ] No type errors / lint warnings
- [ ] Code reviewed (run /review)
