# Checkpoint

> Feature: session-2026-04-19 (project migration + broadcast conflict resolution)
> Last updated: 1776657786
> Plan hash: n/a (maintenance session, no spec)
> Session objective: register caffeine-calculator (migrating from legacy path), broadcast current hub state, and resolve long-standing taxes conflicts.

## Accomplished

- **caffeine-calculator migrated and registered.** Moved `~/Documents/GitHub/caffeine-calculator` → `~/projects/caffeine-calculator`. Registered in hub registry as UUID `4ee230a2-6454-4cbd-bbac-666ff0aac054`. Synced from lockfile version `3344c69` → current (`8f5ad8c` then `4a2458e`). Accepted 4 new hub files (guard-destructive, guard-force-push, ccanvil-pull-globals skill, spec skill).
- **Claude Code conversation history preserved across move.** Renamed `~/.claude/projects/-Users-zacharywright-Documents-GitHub-caffeine-calculator` → `-Users-zacharywright-projects-caffeine-calculator` and rewrote embedded `cwd` fields in all `.jsonl` session files via `sed`.
- **Broadcast hub `4a2458e` to all 6 nodes.** security-audit.sh update propagated to taxes, caffeine-calculator, luxlook, whoop-toolbox, fucina. fieldnation-toolbox was already current.
- **taxes conflicts resolved.** Accepted 3 new hub files (guards, pull-globals skill), took hub's `.claude/settings.json`, re-applied `fastapi-sqlite` stack to restore `protect-db.sh` hook registration in settings. Stack-sourced `protect-db.sh` marked node-only (workaround — see Context Notes). Committed as `8490cf8`.
- **Idea captured:** `pull-plan` mis-classifies files with `origin: stack:<id>` as "removed from hub" because it only scans the hub root.

## Current State

- **Branch:** main
- **Tests:** not run this session (no hub code changes)
- **Uncommitted changes:** `M docs/ideas.md` (idea captures); this checkpoint write.
- **Build status:** clean; all 6 downstream nodes synced to hub `4a2458e`, no pending conflicts

## Blocked On

- Nothing. `pull-plan` stack-origin bug is deferred to a proper spec; workaround in place.

## Next Steps

1. **Triage open ideas** — 2 untriaged (new `/pr`-for-local-repos design question; `pull-plan` stack-origin bug fix). Run `/idea triage` against roadmap.
2. **Dark code idea (8ef0)** still untriaged from last session — Nate B Jones' Three-Layer Solution evaluation against module-manifest direction.
3. **Fix `pull-plan` stack-origin classification.** When resolved, the `node-only` workaround on `taxes/.claude/hooks/protect-db.sh` can be reverted — the file should again be tracked with `origin: stack:fastapi-sqlite`.
4. **Backlog continuation** — BTS-22 (docs directory strategy), checkpoint evolution, BTS-20 (workflow engine).

## Context Notes

- **Legacy project location (`~/Documents/GitHub/`) was outside ccanvil's mental model.** The migration surfaced that `register`'s UUID bootstrap creates `.claude/ccanvil.local.json` as untracked, which blocks the very next broadcast pre-check. Required `ALLOW_MAIN=1 git commit` in the node. Same friction pattern as earlier registration flows.
- **Stack re-apply was necessary after taking hub's `settings.json`.** Hub settings doesn't (and shouldn't) include stack-specific hook entries. After `take-hub`, run `stack-apply <id>` to restore. Could be automated: `pull-apply` could detect active stacks on the node and auto-reinvoke them.
- **Workaround for stack-origin bug (taxes `protect-db.sh` → `node-only`).** File is functionally a stack file, but marked node-only to silence broadcast noise. When the `pull-plan` bug is fixed, revert with `ccanvil-sync.sh track .claude/hooks/protect-db.sh` and re-apply the stack so lockfile origin becomes `stack:fastapi-sqlite` again.
- **Claude Code conversation continuity across project moves is not automatic.** `~/.claude/projects/` is keyed by path-encoded directory name; moving the project strands the history. Worth a future subcommand.

## Determinism Review

- **operations_reviewed:** ~8 (migration, register, broadcast x2, conflict resolution per-file, jsonl rewrite)
- **candidates_found:** 3

- **Claude-Code history relocation after project move:** Claude ran `mv ~/.claude/projects/<old>` and `find ... -exec sed` to preserve conversation continuity. Should be a script: `ccanvil-sync.sh relocate <new-path>` (invoked from the new location) that renames the `~/.claude/projects/` dir and rewrites `cwd` fields in jsonl. Impact: medium — happens on every project move and users won't remember to do it manually.

- **Post-`take-hub` stack re-application:** Claude manually ran `stack-apply fastapi-sqlite` after taking hub's settings.json because the stack's hook entries were wiped. Should be: `pull-apply <file> take-hub` checks lockfile for active stacks on this node and auto-reinvokes `stack-apply` for each. Impact: low-medium — only bites when hub's settings.json changes on a stack-tagged node.

- **Node UUID bootstrap commit during register:** Claude had to manually `ALLOW_MAIN=1 git add/commit` the newly-created `.claude/ccanvil.local.json` in caffeine-calculator before broadcast would proceed. `cmd_register` should commit this file itself (mirror of `commit_hub_file` on the node side). Impact: medium — every first `register` on a gitignore-respecting node hits this.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
