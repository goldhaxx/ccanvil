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
- Completed full fucina sync: 5 auto-updates, 2 section-merges (GUIDE.md + CLAUDE.md), 1 merged conflict (settings.json), 4 new files accepted
- Classified fucina node-only: `sketches.md`, `settings.json`. Re-tracked `SKILL.md` (TDD is core methodology, not project-specific)
- Removed `scaffold.lock` and `scaffold-sync.log` from `.gitignore` in both hub and fucina (tracked as provenance records, still in `.claudeignore`)
- Updated GUIDE.md: hooks system section, deterministic-first diagrams, node-only in status lifecycle, updated sync flows, command tables, decision guide, appendix

## Current State

- **Branch:** main (both repos)
- **Tests:** No test suite exists for scaffold-sync.sh — this is a gap (see Next Steps)
- **Uncommitted changes:** Hub has checkpoint update only. Fucina clean.
- **Build status:** Clean. `bash -n scaffold-sync.sh` passes. Hook scripts smoke-tested.

## Blocked On

- Nothing

## Next Steps

### 1. Add section-merge delimiter to TDD SKILL.md
- Add `<!-- NODE-SPECIFIC-START -->` delimiter to hub's `SKILL.md`
- Hub section: YAML frontmatter + TDD methodology (phases, rules, commit patterns) — universal
- Node section: Project-specific test config (`$TEST_COMMAND` value, test file patterns, framework notes)
- This pattern generalizes to any skill with universal methodology + project-specific configuration
- After adding delimiter in hub, pull to fucina and populate node section with `pio test` config

### 2. Write tests for scaffold-sync.sh
Identified bugs during the fucina sync that tests would have caught:

**Test cases for `pull-plan`:**
- File with delimiter strings inside code (not as standalone lines) should NOT classify as section-merge
- File that exists locally but is not in the lockfile should be flagged differently than a truly new file
- Node-only files should be completely absent from pull-plan output
- Section-merge should only apply to `.md` files

**Test cases for `pull-apply accept-new`:**
- When file already exists locally (but not in lockfile), should WARN instead of silently overwriting
- Accepting a new file should correctly add lockfile entry with proper hashes

**Test cases for `node-only` / `track` / `classify`:**
- Toggle: `node-only` then `track` should restore to tracked state
- `classify` should only list files that are modified/local-only AND not already node-only
- `node-only` on already node-only file should be idempotent (no error)

**Test cases for `section-merge`:**
- File with no local delimiter: entire local content becomes node section
- File with delimiter: hub section replaced, node section preserved
- Non-markdown file with delimiter strings: should NOT be treated as section-merge

**Test infrastructure:**
- Create `tests/scaffold-sync.bats` using [bats-core](https://github.com/bats-core/bats-core) (bash test framework)
- Each test creates a temp directory with mock hub + node repos
- Tests are deterministic — no real git remotes, no real scaffold

### 3. Add `.claude/hooks/*.sh` to TRACKED_PATTERNS
- Hook scripts were manually copied during fucina sync — they should be tracked like other scaffold files
- Add `".claude/hooks/*.sh"` to the TRACKED_PATTERNS array in `scaffold-sync.sh`

### 4. Fix `accept-new` safety for existing files
- `pull-apply accept-new` should check if the file already exists locally before overwriting
- If it exists, warn and suggest section-merge or conflict resolution instead of silent overwrite
- This caused data loss during the fucina sync (had to `git checkout` to recover CLAUDE.md)

### 5. Document bootstrap requirement for scaffold-sync.sh
- During pull, the sync script itself is what runs the commands
- If the script has new commands the old version doesn't know, you must bootstrap: copy the new script first, then run pull
- Document this in GUIDE.md or make the pull command resilient to it

### 6. Pull remaining hub changes to fucina
- Hub has commits since fucina's last sync (Phase 3 docs, gitignore fix, delimiter bug fix)
- Quick `pull-auto` should handle it

## Context Notes

- TDD SKILL.md was incorrectly marked node-only during initial classification. Corrected — TDD is core methodology, only the test command is project-specific. This validates the need for section-merge on skills.
- `settings.json` stays node-only because JSON can't support section delimiters. Hook *scripts* (.sh files) sync normally; only the settings.json *references* to them are project-managed.
- The scaffold hub itself doesn't follow TDD for its own development. This is a gap — scaffold-sync.sh has testable pure functions with deterministic I/O.
