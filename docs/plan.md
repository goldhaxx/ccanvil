# Plan: Safe init with conflict-aware merge planning

> Feature: safe-init
> Spec hash: (from docs/spec.md)
> Created: 1775609444

## Approach

Add two new subcommands (`init-preflight`, `init-apply`) to `ccanvil-sync.sh` and update the `/init` skill to call them instead of blind-copying. The preflight scans both sides and outputs a JSON plan; the apply executes it. Claude's role is limited to presenting the plan and relaying user edits — all file operations are deterministic.

## Key Design Decisions

1. **Preflight scans more than TRACKED_PATTERNS.** The `/init` skill also copies GitHub templates (README.md, CONTRIBUTING.md, .github/), .claudeignore, and lint.json. The preflight must cover these "extra" files too, not just the lockfile-tracked patterns. Solution: define an `INIT_EXTRA_FILES` array for these and scan them alongside tracked patterns.

2. **Section-merge detection mirrors `cmd_pull_plan`.** Check `*.md` files for `<!-- NODE-SPECIFIC-START -->` or `<!-- HUB-MANAGED-START -->` in the hub version. Same logic as lines 750-755 of the current script.

3. **Plan JSON is the single source of truth.** Preflight outputs it, Claude presents it, user may edit actions, then the edited JSON goes to `init-apply`. No intermediate state.

4. **`init-apply` reuses `cmd_migrate`'s copy+merge pattern.** For `section-merge` action: call `cmd_section_merge`. For `copy`/`overwrite`: `mkdir -p` + `cp`. For `skip`: no-op.

## Steps

### Step 1: Add `INIT_EXTRA_FILES` constant
**File:** `preset/.ccanvil/scripts/ccanvil-sync.sh` (near line 33, after `EXCLUDED_FILES`)

Add array of files that `/init` copies but aren't in `TRACKED_PATTERNS`:
```bash
INIT_EXTRA_FILES=(
  ".claudeignore"
  ".claude/lint.json"
)
```
Note: GitHub template files (README.md, CONTRIBUTING.md, .github/*) are handled separately in the skill — they aren't hub-tracked sync files. The preflight will scan them via a dedicated `INIT_GITHUB_TEMPLATES` array that maps source → destination:
```bash
INIT_GITHUB_TEMPLATES=(
  ".ccanvil/templates/github/README.md:README.md"
  ".ccanvil/templates/github/CONTRIBUTING.md:CONTRIBUTING.md"
  ".ccanvil/templates/github/ISSUE_TEMPLATE::.github/ISSUE_TEMPLATE"
  ".ccanvil/templates/github/PULL_REQUEST_TEMPLATE.md:.github/PULL_REQUEST_TEMPLATE.md"
  ".ccanvil/templates/github/workflows/ci.yml:.github/workflows/ci.yml"
)
```

**Test:** None yet (constant only).

### Step 2: Write `cmd_init_preflight` — RED
**File:** `hub/tests/ccanvil-sync.bats`

Write test: `init-preflight with no conflicts shows all copy actions`. Setup: empty node dir, populated hub. Assert: all files have `recommended_action: copy`, summary shows `conflicts: 0`.

**Run test, confirm RED.**

### Step 3: Implement `cmd_init_preflight` — GREEN
**File:** `preset/.ccanvil/scripts/ccanvil-sync.sh`

Add function after `cmd_init` (~line 265). Logic:
1. Accept `hub-path` argument, resolve dist_root
2. Scan hub files via `scan_hub_files` + iterate `INIT_EXTRA_FILES` + `INIT_GITHUB_TEMPLATES`
3. For each file, check if it exists locally:
   - **Local missing** → `{ source: "hub-only", recommended_action: "copy", reason: "New file from hub" }`
   - **Local exists, hash identical** → `{ source: "both", recommended_action: "skip", reason: "Already matches hub" }`
   - **Local exists, hash differs, has delimiter** → `{ source: "both", recommended_action: "section-merge", reason: "Both versions exist; can merge hub and local sections" }`
   - **Local exists, hash differs, no delimiter** → `{ source: "both", recommended_action: "review", reason: "Local differs from hub; needs user decision" }`
4. Also scan local tracked patterns for local-only files → `{ source: "local-only", recommended_action: "skip", reason: "Local file, not in hub" }`
5. Compute summary: `conflicts` = count of `review` actions, `auto` = count of `copy` + `skip` + `section-merge`
6. Output JSON: `{ summary: { conflicts, auto, total }, plan: [...] }`

**Run test, confirm GREEN.**

### Step 4: Test preflight with identical files — RED → GREEN
**File:** `hub/tests/ccanvil-sync.bats`

Test: `init-preflight with identical files recommends skip`. Setup: copy hub files to node first, then run preflight. Assert: matching files have `recommended_action: skip`.

### Step 5: Test preflight with section-merge files — RED → GREEN
**File:** `hub/tests/ccanvil-sync.bats`

Test: `init-preflight detects section-merge candidates`. Setup: create a node `.claude/rules/tdd.md` with different content but same delimiter structure. Assert: `recommended_action: section-merge`.

### Step 6: Test preflight with conflicting files — RED → GREEN
**File:** `hub/tests/ccanvil-sync.bats`

Test: `init-preflight flags review for conflicting non-delimited files`. Setup: create a node `.claude/settings.json` differing from hub's. Assert: `recommended_action: review`, summary shows `conflicts: 1`.

### Step 7: Write `cmd_init_apply` — RED
**File:** `hub/tests/ccanvil-sync.bats`

Test: `init-apply executes copy actions`. Setup: run preflight on empty node, feed plan JSON to apply. Assert: files exist in node after apply.

### Step 8: Implement `cmd_init_apply` — GREEN
**File:** `preset/.ccanvil/scripts/ccanvil-sync.sh`

Add function after `cmd_init_preflight`. Logic:
1. Accept `hub-path` and plan JSON (via stdin or file arg)
2. Resolve dist_root
3. For each entry in plan:
   - `copy` / `overwrite`: `mkdir -p "$(dirname "$file")" && cp "$hub_file" "$file"`
   - `skip`: no-op, log "SKIPPED: $file"
   - `section-merge`: call `cmd_section_merge "$hub_file" "$file"`, write result to `$file`
4. Output results summary: `{ copied: N, skipped: N, merged: N, errors: [] }`

**Run test, confirm GREEN.**

### Step 9: Test init-apply skip action — RED → GREEN
Test: `init-apply skips files with skip action`. Assert: local file unchanged after apply.

### Step 10: Test init-apply section-merge action — RED → GREEN
Test: `init-apply merges delimited files preserving node content`. Setup: node has custom content below delimiter. Assert: after apply, hub section updated, node section preserved.

### Step 11: Test init-apply overwrite action — RED → GREEN
Test: `init-apply overwrites when action is overwrite`. Assert: local file replaced with hub content.

### Step 12: Test no-conflict fast path — RED → GREEN
Test: `init-preflight on empty project returns zero conflicts`. Assert: summary `conflicts: 0`, all actions are `copy`.

### Step 13: Test backward compatibility — full init flow
Test: `full init flow on empty project produces same result as before`. Setup: empty node, run preflight → apply → cmd_init. Assert: lockfile generated, all files present, all statuses clean.

### Step 14: Register subcommands in dispatch table
**File:** `preset/.ccanvil/scripts/ccanvil-sync.sh` (dispatch table ~line 1505)

Add:
```bash
init-preflight)   shift; cmd_init_preflight "$@" ;;
init-apply)       shift; cmd_init_apply "$@" ;;
```

Update usage text in the `*` case.

### Step 15: Update `/init` skill
**File:** `global-commands/init.md`

Replace step 3 (blind copy) with:
```
3a. Run preflight scan:
    .ccanvil/scripts/ccanvil-sync.sh init-preflight ~/projects/ccanvil
3b. If conflicts > 0: present the plan as a table (file | action | reason),
    ask for approval. User can approve, deny (abort), or edit actions.
3c. Execute the plan:
    .ccanvil/scripts/ccanvil-sync.sh init-apply ~/projects/ccanvil < plan.json
    (For no-conflict case, proceed directly without pausing.)
```

Adjust downstream steps (lockfile generation, placeholder replacement) to account for the new flow — placeholders only need replacement on files that were actually copied or merged.

### Step 16: Run full test suite, verify 369+ all green

### Step 17: Commit and activate spec
```
feat(sync): add init-preflight and init-apply for conflict-aware init
```

## Risks

- **GitHub template mapping adds complexity.** The `source:destination` mapping for templates is a new pattern. If it proves unwieldy, fall back to handling them in the `/init` skill (Claude copies them with existence checks) rather than the script.
- **Plan JSON size.** A full preset has ~50+ files. The JSON plan will be ~50 entries. This is fine for Claude to present as a table but worth noting.
- **Stdin vs file for plan JSON.** Passing large JSON via argument has shell limits. Use a temp file: preflight writes to `.ccanvil/init-plan.json`, apply reads from it.

## Out of Scope (per spec)

- Preflight for pull/push (already have pull-plan)
- Interactive TUI
- Backup/rollback (git handles this)
