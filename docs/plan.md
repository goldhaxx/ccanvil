# Implementation Plan: BTS-116 — broadcast-resolve-auto

> Feature: bts-116-broadcast-resolve-auto
> Work: linear:BTS-116
> Created: 1777174600
> Spec hash: b985126c
> Based on: docs/spec.md

## Objective

Add `cmd_broadcast_resolve_auto` to `.ccanvil/scripts/ccanvil-sync.sh` — algorithmically classifies and resolves `.claude/ccanvil.json` conflicts on the current node (take-hub if hash-identical, keep-local if local strictly extends hub, else surface for manual review). Reuses `file_hash` and `cmd_pull_apply`; no new mutation primitives.

## Sequence

### Step 1: Red — fixture-based bats tests for AC-1 through AC-7

- **Test:** New `hub/tests/broadcast-resolve-auto.bats` with one test per AC. Each test sets up a fixture hub + node pair (tmpdirs with stub `.claude/ccanvil.json` files and matching `.ccanvil/ccanvil.lock` content), runs `ccanvil-sync.sh broadcast-resolve-auto` in the node, asserts on JSON output and exit code.
- **Implement:** Test-only commit. Tests fail because the subcommand doesn't exist yet.
- **Files:** `hub/tests/broadcast-resolve-auto.bats` (new).
- **Verify:** `bats hub/tests/broadcast-resolve-auto.bats` — every test fails with "Usage:" or "unknown subcommand".

### Step 2: Green — implement `cmd_broadcast_resolve_auto`

- **Test:** All AC-1 through AC-7 tests pass.
- **Implement:** Add `cmd_broadcast_resolve_auto` function to `ccanvil-sync.sh`:
  - Parse `--dry-run` flag.
  - Check `.ccanvil/ccanvil.lock` exists; if not, exit 2 with stderr (AC-6).
  - Resolve hub path via `get_hub_source_raw`.
  - Compute `local_hash` (`.claude/ccanvil.json`) and `hub_hash` (`$hub_root/.claude/ccanvil.json`) via `file_hash`.
  - **No-conflict branch (AC-7):** if both files missing, emit `resolution: "no-conflict"`, exit 0. If both files exist and `pull-plan` doesn't include the file as conflict, also no-conflict.
  - **Take-hub branch (AC-1):** if `local_hash == hub_hash`, emit JSON, then if not dry-run call `cmd_pull_apply ".claude/ccanvil.json" take-hub`. Exit 0.
  - **Keep-local branch (AC-2):** jq-compute the diff. If `(hub_obj | keys_unsorted)` is a subset of `(local_obj | keys_unsorted)` AND for every key in hub, `local[k] == hub[k]` (deep-equal), emit JSON, then if not dry-run call `cmd_pull_apply ".claude/ccanvil.json" keep-local`. Exit 0.
  - **Requires-review branch (AC-3, AC-4):** else compute `removed_keys` (in hub but not in local) and `divergent_keys` (in both but different values). Emit appropriate JSON, exit 3.
  - Add dispatch case `broadcast-resolve-auto)` in the bottom switch.
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh` (modified).
- **Verify:** Run the new bats file — all green. Then full suite via `bats-report.sh --parallel` — no regressions.

### Step 3: Hub guide entry

- **Test:** N/A — doc step (AC-8 reuse compliance is verified by tests in Step 2; the guide entry is doc hygiene).
- **Implement:** Add a row to `.ccanvil/guide/command-reference.md` for the new `ccanvil-sync.sh broadcast-resolve-auto` subcommand. One-line description mentioning the four resolution states.
- **Files:** `.ccanvil/guide/command-reference.md` (modified).
- **Verify:** Read back the new row in context; not duplicated with existing rows.

### Step 4: Header help-text update

- **Test:** N/A — doc step.
- **Implement:** Add the new subcommand to the inline usage block at the top of `ccanvil-sync.sh` (lines 5-15).
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh` (already in Step 2 scope; one extra line in the header comment).
- **Verify:** `bash ccanvil-sync.sh` (no args) prints usage including `broadcast-resolve-auto`.

## Risks

- **Lockfile-update under `cmd_pull_apply` keep-local.** When `pull-apply ... keep-local` is called, it should mark the lockfile to reflect that local is canonical (i.e., set lockfile entry's hash to `local_hash`). Verify the existing `cmd_pull_apply` does this; if not, the AC-2 test will catch it via lockfile inspection. Mitigation: read existing `cmd_pull_apply keep-local` flow before writing the implementation.
- **Deep-equal jq comparison.** The keep-local check requires structural equality, not string equality, of nested objects. Use `jq -S` (sort keys) on both sides plus `jq -e '($a) == ($b)'`. Mitigation: AC-2 test fixture intentionally uses nested object values to exercise this.
- **JSON output strictness.** Emitting JSON via `jq -n --arg ... '{...}'` not via printf-string-interpolation. Mitigation: code-quality rule already covers this; reuse pattern from `cmd_idea_count`.
- **Dispatch ordering.** New subcommand must be in the long alphabetical list of dispatch cases AND not shadow an existing one. Mitigation: grep for existing `broadcast` cases before adding.

## Definition of Done

- [ ] All 8 acceptance criteria from spec pass.
- [ ] Bats file green (each AC = one test minimum).
- [ ] Full suite green (no regressions in existing `ccanvil-sync.bats`).
- [ ] /review run — substrate change to a high-traffic script.
- [ ] Guide row added.
- [ ] Inline usage header reflects new subcommand.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
