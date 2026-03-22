<!-- Active checkpoint — overwritten each session. See docs/templates/checkpoint.md for format guide. -->

# Checkpoint

> Last updated: 2026-03-22
> Session objective: Implement deterministic manifest verification (7-step TDD plan)

## Accomplished

- **Deterministic manifest verification complete** — all 7 steps of `docs/plan.md` implemented via TDD:
  1. `parse` — extracts `(path, description)` from README markdown tables (3-col and 4-col)
  2. `check-existence` — reports found/missing files, discovers untracked files in tracked directories
  3. `init` — creates `.claude/manifest.lock` with sha256 hashes + git commit SHA
  4. `hash-check` — compares current hashes vs lockfile, categorizes as verified/stale
  5. Stale entries include `git diff` from verified-at commit (fallback for uncommitted changes)
  6. `extract-identity` — shell comment headers, markdown frontmatter + heading, first 3 lines for other types
  7. `check` — full JSON report combining all categories + summary counts; `verify` updates lockfile
- **Integration** — added `manifest-check.sh` to README manifest, documented all subcommands in GUIDE.md, added appendix entry for research basis
- **Lockfile initialized** — `.claude/manifest.lock` tracks 48 entries with hashes
- **Backlog captured** — spec/plan/checkpoint lifecycle linking saved to memory (`project_docs_lifecycle.md`)

## Current State

- **Branch:** main (7 new commits, not pushed)
- **Tests:** 106/106 passing (41 scaffold-sync + 15 security-audit + 12 lint-hook + 9 format-hook + 29 manifest-check)
- **Uncommitted changes:** This checkpoint
- **Build status:** Clean

## Blocked On

- Nothing

## Next Steps

### 1. Spec/plan/checkpoint lifecycle linking (backlog)
- Tighten the relationship between spec.md, plan.md, and checkpoint.md
- Feature IDs + hash-chain validation + `docs-check` script
- See memory `project_docs_lifecycle.md` for full analysis and proposed approach (Option C)

### 2. Sync fucina with new scaffold changes
- Fucina needs: fetch-license.sh, CI template, format-hook, manifest-check.sh, updated /init
- Run `/scaffold-pull` from fucina

### 3. Push both repos to GitHub
- Hub and fucina both have unpushed commits

## Determinism Notes

- **Manifest verification is now maximally deterministic**: Claude's judgment is only invoked for stale descriptions (with a constrained diff) and new entry descriptions (with identity metadata). Everything else — parsing, hashing, existence checks, diffing, identity extraction — is script-based.
- **`check` without lockfile gracefully degrades**: First-run reports all entries as unverified, enabling bootstrap without errors.
- **Real repo check found real issues**: `docs/templates/github/` parsed as a file path (it's a directory), `.claude/lint.json` listed as missing (hub-only, downstream-only file). These are actual manifest inaccuracies the tool correctly flagged.

## Context Notes

- `manifest-check.sh check README.md` currently shows 1 stale (`docs/templates/github/` — directory, not file) and 1 missing from disk (`.claude/lint.json` — exists in downstream projects, not hub). These are known README manifest issues, not bugs in the tool.
- The `check` subcommand combines all primitives but doesn't deduplicate shared logic with `check-existence` and `hash-check`. Could refactor if performance matters, but correctness is complete.
- Fucina's lint.json uses `cppcheck` (not `platformio check`) because the lint hook appends file paths and PlatformIO's `--src-filter` flag expects a different argument format.
