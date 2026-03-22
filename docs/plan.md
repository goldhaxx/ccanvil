# Plan: Node-Only Classification + Fucina Full Sync

> Created: 2026-03-21
> Status: Draft

## Overview

Two interleaved workstreams:
1. **Node-only classification** — build the `sync` field so files can be permanently excluded from sync consideration
2. **Fucina full sync** — push generalizable fucina changes up, pull hub changes down, classify fucina's files

The sync is the proving ground for the classification system. Build just enough to support the sync, then complete the remaining features.

## Problem

The scaffold sync system describes **sync state** (clean, modified, local-only) but not **sync intent**. There's no way to say "this file is intentionally local — stop asking about it." This wastes context every sync cycle on files that will never move.

### Fucina's current state

| File | Status | Intent | Action needed |
|------|--------|--------|---------------|
| `.claude/settings.json` | MODIFIED | Partially tracked — hooks should update, PlatformIO perms are project-specific | Sync hooks section, mark as node-only after |
| `.claude/skills/tdd/SKILL.md` | MODIFIED | Node-only — test command example is intentionally `pio test` | Mark node-only |
| `.claude/rules/sketches.md` | LOCAL | Node-only — firmware-specific workflow | Mark node-only |
| `GUIDE.md` | MODIFIED* | Tracked — hub section should update (section-merge handles this) | Pull via section-merge |

Additionally, the hub has significant new content to push to fucina: hooks system, compound sync commands, deterministic-first rule, hooks reference template, updated slash commands, GUIDE updates.

## Design Decision: Lockfile `sync` field

Add a `sync` field to each lockfile entry: `"tracked"` (default) or `"node-only"`.

```json
{
  ".claude/rules/sketches.md": {
    "origin": "local",
    "scaffold_hash": null,
    "local_hash": "abc123",
    "status": "local-only",
    "sync": "node-only"
  }
}
```

### Why this over alternatives

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Lockfile `sync` field** | Single source of truth, backward-compatible (missing = tracked), separates intent from state | Slightly more complex lockfile schema | **Chosen** |
| `.scaffold-ignore` file | Familiar gitignore pattern | Two sources of truth; loses provenance ("came from scaffold, I chose to keep my version") | Rejected |
| New `node-only` status | Simple, no new fields | Conflates state with intent. A file can be `modified` AND `node-only` — these are orthogonal. | Rejected |

### Behavior changes

| Operation | `sync: "tracked"` (default) | `sync: "node-only"` |
|-----------|---------------------------|---------------------|
| `pull-plan` | Included in plan | **Skipped entirely** |
| `pull-auto` | Auto-updated if clean | **Skipped** |
| `push-candidates` | Listed as candidate | **Skipped** |
| `scaffold-status` | Shows current status | Shows **NODE-ONLY** badge |
| `scaffold-demote` | Changes status to modified | Suggest `node-only` instead |

---

## Implementation Steps

### Phase 1: Build node-only infrastructure (hub)

#### Step 1: Add `sync` field support to lockfile operations
- Update `cmd_lock_add` to accept optional `sync` parameter (default `"tracked"`)
- Update `cmd_init` to default `sync: "tracked"` on all entries
- Backward compatibility: all read operations treat missing `sync` field as `"tracked"`
- **Files:** `scripts/scaffold-sync.sh`
- **Verify:** `scaffold-sync.sh init` produces entries with `sync` field. Existing lockfiles (fucina) still work without it.

#### Step 2: Add `node-only`, `track`, and `classify` commands
- `cmd_node_only <file>`: set `.files[file].sync = "node-only"`, log the change
- `cmd_track <file>`: set `.files[file].sync = "tracked"`, log the change
- `cmd_classify`: output JSON of all modified/local files without `sync: "node-only"` — `{file, status, origin}` per entry. Claude reads this and calls node-only/track for each after user confirms.
- **Files:** `scripts/scaffold-sync.sh`
- **Verify:** Toggle `node-only` ↔ `track` on a file. `classify` lists candidates.

#### Step 3: Update compound commands to respect `sync` field
- `cmd_pull_plan`: skip files where `sync == "node-only"`
- `cmd_push_candidates`: skip files where `sync == "node-only"`
- `cmd_status`: show `NODE-ONLY` badge when `sync == "node-only"`
- **Files:** `scripts/scaffold-sync.sh`
- **Verify:** Mark a file as node-only → it disappears from pull-plan, push-candidates. Status shows NODE-ONLY.

#### Step 4: Add `/scaffold-ignore` slash command
- Confirm with user, run `scaffold-sync.sh node-only <file>`
- **Files:** `.claude/commands/scaffold-ignore.md`

#### Step 5: Update workflow rule with creation-time classification guidance
- When creating new files in tracked scaffold directories, ask: "node-only or tracked?"
- Record the answer with the appropriate script command
- **Why a rule, not a hook:** Classification needs human judgment. Per deterministic-first: judgment → rule, recording → script.
- **Files:** `.claude/rules/workflow.md`

#### Step 6: Commit hub changes
- Single commit with all node-only infrastructure
- **Verify:** Hub repo is clean. `scaffold-sync.sh` help shows new commands.

### Phase 2: Fucina sync (hub ↔ fucina)

#### Step 7: Evaluate fucina → hub push candidates
- Run `scaffold-sync.sh push-candidates` from fucina
- Review the 4 changed files:
  - `settings.json` — MODIFIED, partially generalizable (hook pattern improvement) but the hub already has the new hooks. No push needed.
  - `SKILL.md` — MODIFIED, project-specific test command. No push.
  - `sketches.md` — LOCAL, fully project-specific. No push.
  - `GUIDE.md` — MODIFIED*, node section only. Never push node sections.
- **Expected outcome:** Nothing to push. All changes are project-specific.
- **Verify:** Confirm with user that no fucina changes need to go upstream.

#### Step 8: Pull hub → fucina
- Run from fucina: `scaffold-sync.sh pre-check` then `scaffold-sync.sh pull-plan`
- Expected plan:
  - **Auto-update** (~20 clean files): commands, rules, agents, scripts, templates, SCAFFOLD_FRAMEWORK.md
  - **Section-merge** (1 file): `GUIDE.md` — hub section updates, node section preserved
  - **Conflict** (2 files): `settings.json` (both changed), `SKILL.md` (both changed)
  - **New** (3 files): `deterministic-first.md`, `protect-files.sh`, `format-on-write.sh`, `hooks-reference.md`
- Execute: `pull-auto` for clean files, `pull-apply` for each conflict/new/merge
- **Verify:** All files updated. Fucina's node-specific content preserved.

#### Step 9: Resolve conflicts
- `settings.json`: The hub now has proper hook script references. Fucina needs those PLUS its PlatformIO permissions. Take scaffold version, then re-add PlatformIO permissions. Mark as node-only after.
- `SKILL.md`: Keep fucina's version (project-specific test command). Mark as node-only.
- **Verify:** Both files have correct content. Lockfile updated.

#### Step 10: Classify fucina's files
- Run `scaffold-sync.sh classify` to list remaining unclassified files
- Mark node-only: `settings.json`, `SKILL.md`, `sketches.md`
- Keep tracked: everything else
- **Verify:** `scaffold-sync.sh status` shows NODE-ONLY badges on the right files.

#### Step 11: Finalize and commit
- Run `scaffold-sync.sh pull-finalize` in fucina
- Commit fucina changes
- **Verify:** `scaffold-sync.sh status` shows clean state with NODE-ONLY badges. No pending conflicts.

### Phase 3: Documentation (hub)

#### Step 12: Update GUIDE.md
- Add `NODE-ONLY` to the File Status Lifecycle diagram
- Add `/scaffold-ignore` to the sync command reference table
- Add to Decision Guide: "When should I mark a file as node-only?"
- Add `node-only` / `track` / `classify` to the compound commands in the help output
- **Files:** `GUIDE.md`

#### Step 13: Commit hub documentation
- Single commit with GUIDE updates
- **Verify:** Diagrams render correctly. Tables are accurate.

---

## Definition of Done

### Node-only classification
- [ ] Lockfile entries support `sync: "tracked" | "node-only"` field
- [ ] `node-only` and `track` commands toggle the field
- [ ] `classify` lists unclassified modified/local files as JSON
- [ ] `pull-plan` and `push-candidates` skip node-only files
- [ ] `status` shows NODE-ONLY badge
- [ ] `/scaffold-ignore` slash command works
- [ ] `workflow.md` includes creation-time classification guidance
- [ ] Backward compatible: old lockfiles without `sync` field still work

### Fucina sync
- [ ] No generalizable fucina changes lost (confirmed nothing to push)
- [ ] Hub changes pulled to fucina: hooks, compound commands, deterministic-first rule, updated slash commands, hooks reference, GUIDE updates
- [ ] `GUIDE.md` section-merged: hub documentation updated, node features preserved
- [ ] `settings.json` resolved: hub hook scripts + fucina PlatformIO perms
- [ ] `SKILL.md`, `sketches.md`, `settings.json` marked node-only
- [ ] Fucina's `scaffold-sync.sh status` is clean with appropriate NODE-ONLY badges

### Documentation
- [ ] GUIDE.md updated with node-only feature
- [ ] All done items verified
