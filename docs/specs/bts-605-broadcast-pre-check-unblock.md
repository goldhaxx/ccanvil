# Feature: Unblock ccanvil-sync.sh broadcast across downstream nodes

> Feature: bts-605-broadcast-pre-check-unblock
> Work: linear:BTS-605
> Created: 1782439224
> Subject: Unblock ccanvil-sync.sh broadcast across downstream nodes
> Status: In Progress

## Summary

`bash .ccanvil/scripts/ccanvil-sync.sh broadcast --dry-run` currently fails per-node pre-check on every registered downstream node, leaving the hub→fleet propagation substrate a no-op. Two distinct failure modes drive this: (1) the node-side pre-check treats UNTRACKED files (e.g. Codex CLI's `.agents/`, `.codex/`, `AGENTS.md`) as a dirty-tree blocker even though broadcast never writes outside ccanvil-tracked paths, and (2) the registry has accumulated ~50 stale `tmp.*` entries from prior `mktemp` test runs, polluting broadcast output and consuming iteration budget. This ship narrows the pre-check's dirty-tree definition to tracked-file modifications only, adds a `registry-prune-stale` substrate verb to clean dead entries, and reorders the bootstrap step ABOVE the dirty check so a re-broadcast can self-heal the fleet without per-node manual `ccanvil-pull`.

## Job To Be Done

**When** I push a hub change and run `bash .ccanvil/scripts/ccanvil-sync.sh broadcast` from the hub,
**I want to** have every healthy registered downstream node receive the change without me first running `ccanvil-pull` in each node by hand to clear an untracked-file false-positive,
**So that** broadcast actually broadcasts and BTS-602-style "cleanup-and-propagate" ships land across the fleet in one operator action, not 20.

## Acceptance Criteria

Each criterion is independently testable. Binary pass/fail.

- [ ] **AC-1 (pre-check ignores untracked):** `pre-check` in `ccanvil-sync.sh` no longer fails on `git status --porcelain` lines beginning with `??`. Verified with a fixture: a fresh git repo with no tracked-file modifications but with a NEW untracked file `.agents/foo.md` → `pre-check` exits 0 and stdout contains `OK`.
- [ ] **AC-2 (pre-check still blocks on modified tracked files):** Given a fresh git repo with a TRACKED file modified (`M`) AND an untracked file (`??`), `pre-check` exits non-zero and stderr contains the literal `ERROR: This project has uncommitted changes` AND lists the modified-tracked path in the porcelain output. Regression guard: the untracked-files relaxation must not weaken the tracked-files block.
- [ ] **AC-3 (Given/When/Then: bootstrap-before-dirty reorder, short-circuit semantics pinned):** **Given** a node whose `.ccanvil/scripts/ccanvil-sync.sh` hash differs from the hub's AND whose working tree has BOTH dirty-tracked modifications AND untracked Codex artifacts, **when** the hub runs `ccanvil-sync.sh broadcast`, **then** the per-node bootstrap-detection block runs BEFORE the dirty-tree check, so the node's sync script is upgraded to the hub version BEFORE pre-check evaluates dirty state. **Pinned exit semantics:** the FIRST pre-check call **exits 0** (NOT non-zero) and emits a stdout line containing the literal token `BOOTSTRAPPED:`. The dirty-tree-check block is NOT reached on the first call — bootstrap short-circuits via `exit 0` (matching the current bootstrap block's existing exit behavior at line ~1974). Broadcast's existing logic (line ~3793) sees the `BOOTSTRAPPED:` marker, commits the new sync script, and re-invokes pre-check; the SECOND pre-check call's hashes match, so bootstrap is skipped, and the dirty-tree check runs against the now-new logic — that second-call behavior is governed by AC-1, AC-2, and AC-9, not by AC-3. Verified by: (a) code-shape inspection — the bootstrap block (current ~lines 1953-1976) is reordered to precede the node-dirty-check block (current ~lines 1940-1951) in `cmd_pre_check`; AND (b) a bats test seeds a node with hash-mismatch + dirty-tracked + untracked-Codex, invokes `pre-check` ONCE, and asserts `$status -eq 0`, `$output` contains `BOOTSTRAPPED:`, and `$output` does NOT contain `ERROR: This project has uncommitted changes`.
- [ ] **AC-4 (registry-prune-stale verb):** A new sub-command `bash .ccanvil/scripts/ccanvil-sync.sh registry-prune-stale [--dry-run]` removes every registry entry whose `path` (after `expand_path`) does not exist on disk. Stdout JSON shape: `{pruned: N, kept: M, dry_run: <bool>, pruned_names: [<name>, ...]}`. Verified by: a registry containing 2 real (existing-path) nodes + 3 fake `tmp.X` entries pointing to non-existent paths → `registry-prune-stale` (non-dry-run) removes only the 3 fakes (`.nodes | length` drops from 5 to 2) and returns `{"pruned": 3, "kept": 2, "dry_run": false, "pruned_names": ["tmp.X", "tmp.Y", "tmp.Z"]}`.
- [ ] **AC-5 (broadcast filters stale before iteration):** `cmd_broadcast` filters registry entries whose `path` is empty OR `expand_path` resolves to a non-existent directory BEFORE the per-node iteration loop. Stdout emits one summary line `STALE: N entries skipped (run \`ccanvil-sync.sh registry-prune-stale\` to clean)` instead of one `=== tmp.X ===\n  STALE:` block per stale. Verified by: registry with 1 real node + 3 stale `tmp.X` entries → `broadcast --dry-run` stdout contains exactly ONE `STALE: 3 entries skipped` line AND zero `=== tmp.` headers AND one `=== <real-node> ===` header.
- [ ] **AC-6 (live evidence — Codex artifacts no longer block):** Running `bash .ccanvil/scripts/ccanvil-sync.sh broadcast --dry-run` from the hub against the live registry produces NO `SKIP: pre-check failed` lines whose error includes ONLY `?? .agents/`, `?? .codex/`, `?? AGENTS.md` in the porcelain output. Verified by parsing stdout: every `SKIP: pre-check failed` block's accompanying `git status --porcelain` excerpt must include at least one non-`??`-prefixed line (i.e., a real tracked-file modification, not just Codex artifacts). Live-API gate (per `.claude/rules/tdd.md`): must run against the actual current registry as part of pre-merge verification.
- [ ] **AC-7 (full suite pass):** `bash .ccanvil/scripts/bats-report.sh --parallel` exits 0 — zero failures, zero errors. The existing `pre-check: fails when node has uncommitted changes` test in `hub/tests/ccanvil-sync.bats` is amended so its fixture creates a TRACKED modification (not an untracked file), preserving the regression intent under the new ordering.
- [ ] **AC-8 (manifest validate clean):** `bash .ccanvil/scripts/module-manifest.sh validate --json` returns `status:"ok"` with `drift == []`. Any new manifest entries on `cmd_pre_check`, `cmd_broadcast`, and the new `cmd_registry_prune_stale` declare `caller:` / `input:` / `output:` / `failure-mode:` / `side-effect:` per the manifest substrate (Layer 2). The `.ccanvil/manifest-allowlist.txt` already includes `.ccanvil/scripts/ccanvil-sync.sh`; new sub-command needs its own `@manifest` block.
- [ ] **AC-9 (error — bootstrap-before-dirty preserves bootstrap idempotence):** When the hub and node sync-script hashes already match (no bootstrap needed) AND the node has only an untracked file, `pre-check` exits 0 with `OK` and does NOT print `BOOTSTRAPPED:`. Verified by a bats test: seed an identical sync script on both sides + untracked file in node → `pre-check` stdout is exactly `OK` (no spurious bootstrap message).
- [ ] **AC-10 (error — registry-prune-stale with --dry-run is read-only):** `registry-prune-stale --dry-run` against a registry with stale entries returns the prune envelope with `"dry_run": true` AND the registry file's content hash (via `shasum -a 256`) is byte-identical pre and post invocation.
- [ ] **AC-11 (drift-guard):** A new `hub/tests/broadcast-pre-check-untracked.bats` file pins AC-1, AC-2, AC-3, AC-4, AC-5, AC-9, AC-10 as re-runnable tests. Added to the bats suite via auto-discovery from `hub/tests/`.
- [ ] **AC-12 (cleanup happens this PR):** After the substrate fix lands but BEFORE the `/ship` step, the hub operator runs `bash .ccanvil/scripts/ccanvil-sync.sh registry-prune-stale` once against the current registry. The 50 stale `tmp.*` entries are dropped to ≤ 5 (allowing for any that may legitimately still exist as in-flight tests). This is verified by the operator (manual step documented in the PR body), not by an AC-checker, since the registry is gitignored machine-local state.

## Affected Files

| File | Change |
|------|--------|
| `.ccanvil/scripts/ccanvil-sync.sh` | Modified — `cmd_pre_check` reorders bootstrap before dirty check + ignores `??` lines in dirty-porcelain; adds `cmd_registry_prune_stale`; `cmd_broadcast` filters stale before iteration |
| `hub/tests/broadcast-pre-check-untracked.bats` | New — drift-guard for AC-1/2/3/4/5/9/10 |
| `hub/tests/ccanvil-sync.bats` | Modified — amend `pre-check: fails when node has uncommitted changes` to use a TRACKED modification, preserving the regression intent |

## Dependencies

- **Requires:** existing pre-check + broadcast substrate. No new substrate deps.
- **Blocked by:** none. This PR itself is the blocker for BTS-603's hub-shared `.claude/settings.json` trim reaching downstream nodes.

## Out of Scope

- **Operator-side gitignore additions on individual downstream nodes** for `.agents/`, `.codex/`, `AGENTS.md`. The pre-check fix is universal — it doesn't matter whether the node gitignores these or not. Per-node gitignore policy is the node operator's call.
- **Adding `.agents/`, `.codex/`, `AGENTS.md` to the hub's own `.gitignore`** — the hub `.gitignore` doesn't propagate to existing nodes via broadcast (only via fresh `init`), so this would help future init'd nodes only. Captured as a follow-up consideration; not required for AC-6.
- **Hub→node `.gitignore` broadcast.** `.gitignore` is in `INIT_EXTRA_FILES` (init-only), not `TRACKED_PATTERNS` (broadcast-eligible). Promoting it is a separate design decision.
- **`unifi-toolbox`-style stale tracked-file modifications** (e.g. `M .ccanvil/scripts/ccanvil-sync.sh` from a prior partial sync). These are real dirty state and SHOULD continue to block pre-check (AC-2 explicitly guards). Cleaning them is a per-node operator action.
- **Self-healing fleet without operator action.** Even with the bootstrap-before-dirty reorder, the FIRST broadcast after this ship still requires each node's existing pre-check to either run the new (post-reorder) logic OR have already been bootstrapped. Documented in the PR body — one full-fleet `ccanvil-pull` cycle may be needed to seed; subsequent broadcasts then self-heal.

## Implementation Notes

- **Pattern: small surgical edit + new sub-command + bats drift-guard.** Same shape as BTS-602: identify the structural defect, change the minimum code, add a re-runnable test pinning the invariant.
- **Pre-check ignore-untracked filter** (`cmd_pre_check`): change `node_dirty=$(git status --porcelain 2>/dev/null)` to `node_dirty=$(git status --porcelain 2>/dev/null | grep -v '^??' || true)`. The `|| true` is required because `grep -v` returns 1 when no lines match (all-untracked case).
- **Bootstrap-before-dirty reorder** (`cmd_pre_check`): move the bootstrap block (current ~lines 1953-1976) above the node-dirty-check block (~1940-1951). Hub-dirty check stays first.
- **`registry-prune-stale` sub-command:** new function `cmd_registry_prune_stale` parallel in shape to `cmd_registry`. Reads registry, iterates `.nodes`, builds the survivors object via jq, atomic-writes via `mktemp + mv`. Emits the envelope JSON on stdout. `--dry-run` skips the mv.
- **Broadcast stale-filter** (`cmd_broadcast`): compute `live_entries` and `stale_count` via jq before the iteration loop (instead of `STALE` detection inside the loop). Print `STALE: <N> entries skipped ...` once if `stale_count > 0`. Update the existing AC-6 detect block to remove the per-entry STALE printout (now redundant).
- **Manifest impact:** `cmd_pre_check` and `cmd_broadcast` get new contract bullets (e.g. `contract: ignores-untracked-files-in-dirty-tree-check`). `cmd_registry_prune_stale` is a fresh entry with full manifest block (purpose, input, output, exit-codes, caller, depends-on, side-effect, failure-mode, contract, anchor).
- **Live verification (AC-6):** the spec is contract-uncertain on whether ALL stale-block-only nodes will go green after the fix — some nodes may have additional tracked modifications. AC-6 is phrased to allow that. The pre-merge live run is the empirical proof.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
