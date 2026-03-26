# Checkpoint

> Feature: activate-commit-sequencing
> Last updated: 1774554110
> Plan hash: 82017376
> Session objective: BTS-28 (activate commit sequencing)

## Accomplished

### BTS-28 complete (all 10 ACs pass, merged to main, PR #6)
- Replaced blanket clean-worktree guard with targeted check — allows uncommitted `docs/specs/` and `docs/spec.md` while rejecting other dirty files
- Added auto-commit on feature branch after activation (`docs(lifecycle): activate <id>`)
- Added error handling for git commit failure
- Fixed `docs_rel` empty-prefix edge case (repo-root docs dir)
- 7 new tests, 2 updated tests, 352/352 passing
- Squash-merge simulation test (AC-10) proves no divergence
- Code review: fixed blocking issue (empty prefix), commit error handling, fragile test assertion
- Security audit: PASS

## Current State

- **Branch:** `main`
- **Tests:** 352/352 passing
- **Uncommitted changes:** This checkpoint + spec completion
- **Build status:** Clean

## Blocked On

- Nothing

## Next Steps

1. **BTS-23:** CLAUDE.md content review — trim to 80-line budget (Medium, needs-spec)
2. **BTS-27:** scaffold-sync.sh bootstrap hash auto-update (Low, needs-spec)
3. **BTS-25:** operations.sh exec subcommand (Low, needs-spec)
4. **BTS-22:** Docs directory strategy (Medium, needs-research)
5. Sync BTS-28 changes to downstream nodes (fucina, luxlook)

## Context Notes

- The git divergence workaround (`git pull --rebase` + `git rebase --skip`) is no longer needed — activate now commits on branch
- Downstream nodes still have the old `cmd_activate` — next `/scaffold-pull` on each node will pick up the fix via `scripts/docs-check.sh` auto-update
- The `--untracked-files=all` flag is used in the targeted worktree check; this is safe for the activate context (small, focused repos)

## Determinism Review

- **operations_reviewed:** 6
- **candidates_found:** 0
- All implementation was direct script edits. Tests ran via `bats`. No manual cp, jq, shasum, or git -C improvised. Code review ran via sub-agent. Security audit ran via script. No candidates this session.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /scaffold-pull. -->
