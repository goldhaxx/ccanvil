# Feature: Flatten Hub Architecture

> Feature: flatten-hub-architecture
> Created: 1776057826
> Status: Draft

## Summary

Eliminate the `preset/` subdirectory so the hub repo root IS the distributable preset. Files currently at `preset/.claude/`, `preset/.ccanvil/`, and `preset/CLAUDE.md` move to `.claude/`, `.ccanvil/`, and `CLAUDE.md` at the repo root. Both symlinks are deleted. The hub becomes a self-hosting ccanvil node — it consumes its own output by construction, not by manual copy.

## Job To Be Done

**When** adding or modifying preset files (rules, commands, skills, agents, hooks, scripts),
**I want to** work with one copy of each file at the repo root,
**So that** the hub automatically uses what it distributes — zero drift, no symlinks, no manual sync.

## Acceptance Criteria

- [ ] **AC-1:** `preset/` directory does not exist. All files previously at `preset/.claude/`, `preset/.ccanvil/`, and `preset/CLAUDE.md` are at `.claude/`, `.ccanvil/`, and `CLAUDE.md` at the repo root.
- [ ] **AC-2:** `.ccanvil` is a real directory (not a symlink). `.ccanvil → preset/.ccanvil` symlink is deleted.
- [ ] **AC-3:** `hub_dist_root` function is deleted from `ccanvil-sync.sh`. All call sites (`cmd_init_preflight`, `cmd_init_apply`, `cmd_migrate`, `scan_hub_files`, `get_hub_source`) use the hub root path directly.
- [ ] **AC-4:** Given a downstream node with `hub_source` pointing to the flattened hub, `ccanvil-sync.sh pull-plan` returns the correct file list with valid hashes.
- [ ] **AC-5:** Given a downstream node, `ccanvil-sync.sh init <hub-path>` generates a lockfile with correct `hub_hash` values matching files at `<hub-path>/.claude/` (not `<hub-path>/preset/.claude/`).
- [ ] **AC-6:** All 406+ bats tests in `hub/tests/` pass against the flattened layout.
- [ ] **AC-7:** Hub `CLAUDE.md` Architecture section accurately describes the flattened layout (no references to `preset/` or the `.ccanvil` symlink).
- [ ] **AC-8:** `.ccanvil/guide/` documentation has zero references to `preset/` as a directory path.
- [ ] **AC-9 (edge):** `scan_hub_files` called on the flattened hub root does not accidentally include files under `hub/` (tests, specs, meta) in the tracked file set.
- [ ] **AC-10 (edge):** Downstream nodes already initialized against the pre-flatten hub (lockfile has `hub_source: ~/projects/ccanvil`) can `pull-plan` successfully after flatten — no stale `preset/` path resolution.

## Affected Files

| File | Change |
|------|--------|
| `preset/.claude/*` | Moved to `.claude/` (reconcile with existing hub copies) |
| `preset/.ccanvil/*` | Moved to `.ccanvil/` (replaces symlink target) |
| `preset/CLAUDE.md` | Merged into root `CLAUDE.md` |
| `.ccanvil` (symlink) | Deleted, replaced by real directory |
| `docs/specs` (symlink) | Deleted, replaced by real directory or direct path |
| `.ccanvil/scripts/ccanvil-sync.sh` | `hub_dist_root` deleted, ~7 call sites updated |
| `CLAUDE.md` | Architecture section rewritten |
| `.ccanvil/guide/*.md` | Remove `preset/` path references |
| `hub/tests/*.bats` | Update any fixtures referencing `preset/` paths |
| `.claude/settings.json` | Single copy, hub-specific overrides move to `settings.local.json` |
| `.claude/manifest.lock` | Path audit |

## Dependencies

- **Requires:** Nothing — this is a structural migration with no external dependencies
- **Blocked by:** Nothing

## Out of Scope

- Changes to downstream node projects (fucina, luxlook, etc.) — their lockfiles point to the hub root, not `preset/`
- Restructuring `hub/` directory (tests, specs, meta stay as-is)
- npm/pip packaging of the preset (horizon item, not current)
- Init bugs (BTS-68, BTS-69) — will be fixed post-flatten against the new structure

## Implementation Notes

- **Migration order:** (1) delete `.ccanvil` symlink, (2) move `preset/.ccanvil/` to `.ccanvil/`, (3) reconcile `preset/.claude/` into `.claude/`, (4) merge CLAUDE.md files, (5) delete `preset/`, (6) update `ccanvil-sync.sh`, (7) update guide docs, (8) run full test suite
- **`hub_dist_root` is the only abstraction to remove.** It has a fallback branch (`else echo "$hub_path"`) that nodes already hit today. After flatten, all callers use the hub root directly — same behavior the fallback provided.
- **Downstream lockfiles are safe.** They store `hub_source: ~/projects/ccanvil` (repo root). Today `hub_dist_root` appends `/preset` for the hub. After flatten, it resolves to the root directly. Node behavior is unchanged.
- **`docs/specs` symlink:** Currently points to `../hub/specs`. After flatten, either make `docs/specs/` a real directory (move specs) or keep the symlink (it doesn't depend on `preset/`). Evaluate during implementation.
- **settings.json reconciliation:** Hub's copy has a bats filter that preset's doesn't. Move the bats filter to `settings.local.json` (gitignored), keep one `settings.json`.
