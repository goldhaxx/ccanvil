<!-- Active checkpoint — overwritten each session. See docs/templates/checkpoint.md for format guide. -->

# Checkpoint

> Last updated: 2026-03-22
> Session objective: Universal delimiters, tests, sync safety, self-review framework, fucina sync

## Accomplished

- Added `<!-- NODE-SPECIFIC-START -->` delimiter to all 23 synced markdown files (5 rules, 10 commands, 3 agents, 1 skill, 4 templates)
- Fixed code-block delimiter false match in GUIDE.md (HTML-escaped to avoid `grep -qx` match)
- Updated GUIDE.md: "Universal Delimiters" section with component table, creation guidance, appendix entry
- Created `tests/scaffold-sync.bats` — 32 bats tests, all passing
- Fixed `accept-new` to refuse overwriting existing local files
- Added `.claude/hooks/*.sh` to TRACKED_PATTERNS
- Documented bootstrap requirement in GUIDE.md and scaffold-pull command
- Synced fucina: 25 auto-updates, 1 conflict resolved, 2 hooks re-tracked
- `pre-check` now enforces both hub and node trees are clean
- `pull-finalize` auto-commits with structured message listing all synced files
- `pre-check` auto-bootstraps stale sync script from hub (no more manual `cp`)
- `pull-plan` distinguishes `adopt-clean` (identical local copy) from `adopt-conflict` (different local copy) — eliminates stochastic diagnosis during sync
- Created `/scaffold-audit` command for on-demand determinism analysis
- Created `self-review.md` rule for continuous stochastic surface area flagging
- Integrated self-review into `/catchup` and `/review`
- Updated CLAUDE.md with tech stack (bash/bats-core) and test commands

## Current State

- **Branch:** main (hub)
- **Tests:** 32/32 passing (`bats tests/scaffold-sync.bats`)
- **Uncommitted changes:** This checkpoint only
- **Build status:** Clean
- **Fucina:** Synced to hub @ ef38ff4 (but hub has 4 more commits since — needs another pull)

## Blocked On

- Nothing

## Next Steps

1. **Pull latest hub changes to fucina** — Hub has 4 commits since fucina's last sync (clean-tree enforcement, auto-bootstrap, adopt-clean/conflict, self-review framework). Run `/scaffold-pull` from fucina.
2. **Publish repos to GitHub** — Enables browsable sync history via commit diffs. Both hub and fucina.
3. **Evaluate sync log redundancy** — Now that `pull-finalize` auto-commits with file lists, the `.claude/scaffold-sync.log` may be redundant. Compare what each provides before deciding.
4. **Add push-side tests** — `push-candidates`, `push-apply`, `promote`, `demote` lack test coverage.
5. **Continue with next feature work** — The scaffold infrastructure is solid. Next session can focus on actual project features.

## Determinism Notes

- **Sync log vs git history**: `pull-finalize` now auto-commits with structured messages. The sync log file (`.claude/scaffold-sync.log`) provides a quick-glance flat file but duplicates git history. Evaluate whether to keep, merge, or remove.
- **adopt-conflict resolution**: When `pull-plan` returns `adopt-conflict`, the user must choose take-scaffold or merge. This is a correct judgment call — no further automation needed.
- **Code-block delimiter safety**: Files that document the delimiter syntax (like GUIDE.md) must use HTML entities (`&lt;!--`) in examples, not raw HTML comments. A test for this specific case would prevent regression.

## Context Notes

- bats-core installed via `brew install bats-core` (v1.13.0)
- The `accept-new` safety check caught a real issue during fucina sync — hook files existed locally but weren't in the lockfile. The new `adopt-clean`/`adopt-conflict` actions handle this deterministically.
- Bootstrap is now fully deterministic: `pre-check` compares script hashes and auto-copies if stale. Exits with "BOOTSTRAPPED" so the user re-runs with the updated script.
- The self-review rule (`self-review.md`) is lightweight — it doesn't run `/scaffold-audit`, just reminds Claude to flag stochastic interventions during checkpoints and reviews.
