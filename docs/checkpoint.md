<!-- Active checkpoint — overwritten each session. See docs/templates/checkpoint.md for format guide. -->

# Checkpoint

> Last updated: 2026-03-21
> Session objective: Implement universal delimiters, tests, accept-new safety, hooks tracking, bootstrap docs

## Accomplished

- Added `<!-- NODE-SPECIFIC-START -->` delimiter to all 23 synced markdown files (5 rules, 10 commands, 3 agents, 1 skill, 4 templates)
- Fixed false delimiter match in GUIDE.md code-block example (HTML-escaped to avoid `grep -qx` match)
- Updated GUIDE.md: renamed "Document Inheritance" to "Universal Delimiters", added component table, creation guidance, "what doesn't get delimiters" rationale, updated appendix entry
- Created `tests/scaffold-sync.bats` — 23 bats tests covering section-merge (6), pull-plan (6), node-only/track (4), accept-new (2), init (3), hash (2)
- Fixed `accept-new` to refuse overwriting existing local files (was the cause of data loss during fucina sync)
- Added `.claude/hooks/*.sh` to TRACKED_PATTERNS (hook scripts now sync like other scaffold files)
- Documented bootstrap requirement for scaffold-sync.sh in GUIDE.md and scaffold-pull command (Step 0)

## Current State

- **Branch:** main
- **Tests:** 23/23 passing (`bats tests/scaffold-sync.bats`)
- **Uncommitted changes:** This checkpoint only
- **Build status:** Clean. `bash -n scripts/scaffold-sync.sh` passes.

## Blocked On

- Nothing

## Next Steps

1. **Pull hub changes to fucina** — Run `/scaffold-pull` from the fucina project. Many files will need section-merge (all the new delimiters). Bootstrap the new scaffold-sync.sh first.
2. **Add test command to CLAUDE.md** — Now that we have a test suite, add `bats tests/scaffold-sync.bats` to the Commands section.

## Context Notes

- The code-block example in GUIDE.md that shows the delimiter syntax uses HTML entities (`&lt;!--`) instead of raw HTML comments to avoid `grep -qx` matching the example as a real delimiter. This is important — raw delimiters inside fenced code blocks are still matched by `sed` and `grep` since they don't understand markdown structure.
- `accept-new` safety: the fix uses `die` (exits non-zero) when the file already exists. The error message suggests `take-scaffold` or `section-merge` as alternatives. This prevents the silent overwrite that burned us during the initial fucina sync.
- bats-core was installed via `brew install bats-core` (v1.13.0).
