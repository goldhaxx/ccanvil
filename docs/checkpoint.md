<!-- Active checkpoint — overwritten each session. See docs/templates/checkpoint.md for format guide. -->

# Checkpoint

> Last updated: 2026-03-21
> Session objective: Implement deterministic-first principle, hooks system, compound sync commands, node-only classification, and full fucina sync

## Accomplished

- Created `.claude/rules/deterministic-first.md` — core principle: scripts/hooks over Claude reasoning for computable operations
- Created `.claude/hooks/protect-files.sh` (PreToolUse blocker, exit 2) and `.claude/hooks/format-on-write.sh` (PostToolUse formatter)
- Fixed `settings.json`: proper hook script references, exit 1→2 for blocking
- Created `docs/templates/hooks-reference.md` — complete hooks documentation (events, exit codes, matchers, schemas)
- Added 10 compound commands to `scaffold-sync.sh`: `pre-check`, `pull-plan`, `pull-auto`, `pull-apply`, `pull-finalize`, `push-candidates`, `push-apply`, `push-finalize`, `promote`, `demote`
- Rewrote all sync slash commands (pull, push, promote, demote) to call compound commands — Claude only for judgment calls
- Added node-only classification: `sync` field in lockfile, `node-only`/`track`/`classify` commands, `/scaffold-ignore` slash command
- Updated `workflow.md` with creation-time classification guidance
- Fixed bug: section-merge delimiter detection restricted to `.md` files (was false-positive matching inside scaffold-sync.sh)
- Completed full fucina sync: 5 auto-updates, 2 section-merges (GUIDE.md + CLAUDE.md), 1 merged conflict (settings.json), 4 new files accepted, 3 files classified node-only
- Removed `scaffold.lock` and `scaffold-sync.log` from `.gitignore` in both hub and fucina (now tracked as provenance records, still in `.claudeignore`)
- Updated GUIDE.md: hooks system section, deterministic-first diagrams, node-only in status lifecycle, updated sync flows, command tables, decision guide, appendix

## Current State

- **Branch:** main (both repos)
- **Tests:** N/A (scaffold config project, no test suite)
- **Uncommitted changes:** No (both repos clean, fucina has 2 unrelated sketch file modifications from earlier work)
- **Build status:** Clean. `bash -n scaffold-sync.sh` passes. Hook scripts tested (exit 2 for blocked, exit 0 for allowed).

## Blocked On

- Nothing

## Next Steps

1. **Pull latest GUIDE.md and .gitignore changes to fucina** — hub has 2 new commits (Phase 3 docs + gitignore fix) since fucina's last sync. Quick `pull-auto` should handle it.
2. **Add `.claude/hooks/*.sh` to TRACKED_PATTERNS** in `scaffold-sync.sh` — hook scripts are currently copied manually during sync. They should be tracked like other scaffold files.
3. **Consider a PostToolUse hook or Stop hook for test running** — now that the hooks infrastructure exists, auto-running tests after file edits is the next high-value deterministic automation.
4. **`docs/plan.md` still has the node-only plan** — can be cleared or archived once you're satisfied with the implementation.

## Context Notes

- During fucina sync, we had to **bootstrap** the new `scaffold-sync.sh` by manually copying it before the pull (chicken-and-egg: need new script to run new commands). This is an inherent limitation — the sync script itself must be copied first. Consider documenting this in GUIDE.md or making `scaffold-pull` resilient to it.
- The `accept-new` action for CLAUDE.md overwrote fucina's customized version with the scaffold template. Had to `git checkout` to restore and then section-merge properly. Lesson: `pull-plan` should flag existing untracked files when it reports "new" — the file might exist locally but not in the lockfile.
- `settings.json` was marked node-only because JSON can't support section delimiters. Hook *scripts* (.sh files) sync normally; only the settings.json *references* to them are project-managed.
- Fucina's `.claude/rules/sketches.md`, `.claude/skills/tdd/SKILL.md`, and `.claude/settings.json` are now permanently classified as node-only — they won't appear in future sync operations.
