# Implementation Plan: Global Commands Sync

> Feature: global-commands-sync
> Created: 1776388358
> Spec hash: 83a33058
> Based on: docs/spec.md

## Objective

Rename the hub's global command to `ccanvil-init` and add an opt-in `pull-globals` subcommand that propagates hub-owned `ccanvil-*.md` files to `~/.claude/commands/` without touching user-owned files.

## Sequence

### Step 1: Rename the hub's global command (AC-1)
- **Test:** `hub/global-commands/ccanvil-init.md` exists; the stale `init.md` does not. First line references `/ccanvil-init` naming.
- **Implement:** `git mv global-commands/init.md global-commands/ccanvil-init.md`. Update line 1 to reflect new command name: `Initialize a new project using the ccanvil preset located at ~/projects/ccanvil. (Invoked as /ccanvil-init.)`
- **Files:** `global-commands/ccanvil-init.md`, deletion of `global-commands/init.md`
- **Verify:** `ls global-commands/` shows renamed file.

### Step 2: cmd_pull_globals — happy path (AC-3, AC-8)
- **Test:** Given `global-commands/ccanvil-init.md` exists and `~/.claude/commands/` is empty, `pull-globals` copies the file and outputs `{copied:1, skipped:0, conflicts:0}`. Creates `~/.claude/commands/` if missing. Errors clearly if `$HOME` unset.
- **Implement:** Add `cmd_pull_globals()` in `ccanvil-sync.sh`:
  - Resolve hub root from lockfile (via `get_hub_source`)
  - Require `$HOME` non-empty, else `die`
  - Ensure `$HOME/.claude/commands/` exists (`mkdir -p`)
  - Iterate `<hub>/global-commands/ccanvil-*.md` with `nullglob`
  - For each file: if target doesn't exist → copy, increment `copied`
  - Output JSON summary
  - Add dispatch entry `pull-globals) cmd_pull_globals "$@" ;;`
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh`, `hub/tests/pull-globals.bats` (new)
- **Verify:** Tests pass. Manual: `bash .ccanvil/scripts/ccanvil-sync.sh pull-globals` produces expected JSON.

### Step 3: Conflict detection — skip modified files without --force (AC-4)
- **Test:** Given a local `ccanvil-init.md` that differs from the hub version, `pull-globals` (no flags) leaves the local file unchanged, outputs `{copied:0, skipped:0, conflicts:1}`, and prints the diff to stderr. Exit code 0.
- **Implement:** In `cmd_pull_globals` loop, when target exists compare hashes via `file_hash()`. If equal → skip (count skipped). If different → report conflict, print `diff -u "$hub" "$local"` to stderr, count conflicts, do NOT overwrite.
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh`
- **Verify:** Tests pass.

### Step 4: --force flag (AC-5)
- **Test:** `pull-globals --force` overwrites a conflicted local file with the hub version; reports `{copied:1, conflicts:0}`.
- **Implement:** Parse `--force` flag at the start of `cmd_pull_globals`. Branch in the conflict path: if `$force` → copy and count as copied.
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh`
- **Verify:** Tests pass.

### Step 5: User namespace is sacrosanct (AC-6)
- **Test:** Create `~/.claude/commands/my-personal-command.md` (not `ccanvil-*`). Also create `~/.claude/commands/init.md` (bare name collision with a hypothetical un-prefixed hub file). Run `pull-globals`. Both files remain untouched, even with `--force`.
- **Implement:** Already covered by the glob pattern `ccanvil-*.md` limiting iteration scope; verify that no code path writes to non-`ccanvil-*` target names. Add an explicit test.
- **Files:** `hub/tests/pull-globals.bats`
- **Verify:** Tests pass.

### Step 6: Skill wrapper (AC-7)
- **Test:** File `.claude/skills/ccanvil-pull-globals/SKILL.md` exists with valid frontmatter (`name`, `description`). Body describes invoking the script and interpreting results.
- **Implement:** Create `.claude/skills/ccanvil-pull-globals/SKILL.md` — short skill that runs the script, reads the JSON, and formats output. Follow `radar/SKILL.md` style.
- **Files:** `.claude/skills/ccanvil-pull-globals/SKILL.md` (new)
- **Verify:** `manifest-check.sh` (if run) sees the new skill; `/ccanvil-pull-globals` is listed as an available skill.

### Step 7: Update usage help + command reference doc
- **Implement:** Add `pull-globals [--force]` to the usage block in `ccanvil-sync.sh` and to `.ccanvil/guide/command-reference.md` under "Registry & Node Identity" or a new "Global Commands" section.
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh`, `.ccanvil/guide/command-reference.md`
- **Verify:** `docs-check.sh validate` passes.

### Step 8: Apply to the hub machine (one-time manual, post-merge)
- **Implement:** After merge, the user runs:
  ```bash
  mv ~/.claude/commands/init.md ~/.claude/commands/ccanvil-init.md
  bash ~/projects/ccanvil/.ccanvil/scripts/ccanvil-sync.sh pull-globals
  ```
  This resyncs the renamed file and exercises the new pull flow end-to-end on live data.
- **Files:** None (runtime operation)
- **Verify:** `ls ~/.claude/commands/` shows `ccanvil-init.md`, not `init.md`.

### Step 9: Regression sweep (AC-9)
- **Test:** `bats hub/tests/` — all green.
- **Implement:** Fix any regressions.
- **Files:** Any
- **Verify:** 511+ tests passing (501 existing + new pull-globals suite).

## Risks

- **Bare-name collision with `/init`:** Claude Code has built-in `/init` (different meaning: initializes a CLAUDE.md file). Renaming ours to `ccanvil-init` eliminates the collision — actually a win.
- **`$HOME` unset in CI/containers:** Guarded by AC-8's error path. `die "\$HOME not set"` keeps the script deterministic.
- **Hub `global-commands/` path assumption:** If `get_hub_source()` returns a path with `~` prefix, resolving relative paths might fail. Mitigate with existing `expand_path` helper.
- **One-time manual rename of active file:** Step 8 is a runtime op the user must execute post-merge. Document explicitly in the PR body so it isn't missed.

## Definition of Done

- [ ] All 9 acceptance criteria pass
- [ ] All existing tests still pass
- [ ] Skill invocable as `/ccanvil-pull-globals`
- [ ] Post-merge manual rename completed; `pull-globals` works end-to-end on hub machine
- [ ] Code reviewed (run /review)
