# Feature: Auto-complete spec on merge

> Feature: auto-complete-spec-on-merge
> Created: 1776905781
> Status: In Progress

## Summary

Close the loop between `/pr` and the spec archive. Today, `/pr` removes the active lifecycle docs and commits, but `docs/specs/<id>.md` stays at `Status: In Progress` after the PR merges. Every session after that shows `backlog.in_progress: 1` and requires a manual `docs-check.sh complete <id>` to clear. Flagged in three consecutive stases (BTS-114). Fix: make `/pr` transition the archive via `cmd_complete` on the feature branch (primary path, lands via squash-merge), and add a safety-net scan in `cmd_land` for edge cases where `/pr` was skipped.

## Job To Be Done

**When** a feature PR is merged,
**I want to** see its spec archive transition to `Complete` automatically,
**So that** `list-specs` and `radar-gather` reflect the true state without a manual cleanup step.

## Acceptance Criteria

- [ ] **AC-1:** When `/pr` runs with `docs/spec.md` present, the skill invokes `docs-check.sh complete <feature-id>` (feature-id parsed from `docs/spec.md` metadata) instead of the manual `rm + commit` dance. `cmd_complete` handles the transition, lifecycle-doc cleanup, and commit.
- [ ] **AC-2:** When `/pr` runs with no `docs/spec.md` (validate says `no-active-spec`), the skill preserves current behavior — no archive transition, no failure.
- [ ] **AC-3:** Given `cmd_land` has just switched to main after a verified-merged PR, when any spec in `docs/specs/*.md` whose `feature_id` matches the just-deleted branch's tail segment has `Status: In Progress`, then `cmd_land` transitions it to `Complete`.
- [ ] **AC-4:** When `cmd_land`'s safety-net transition fires, it commits on main via `ALLOW_MAIN=1 git commit -m "docs(lifecycle): complete <id> — post-merge cleanup"` and pushes to origin (if origin configured).
- [ ] **AC-5:** When the primary path (AC-1) already transitioned the archive before merge, `cmd_land` finds no `In Progress` specs matching the branch and makes no commit.
- [ ] **AC-6:** Edge: when `cmd_land` cannot parse a feature_id from the branch name (e.g., branch `hotfix/foo`, missing `claude/<type>/<id>` pattern), it skips the safety-net scan silently — no error, no commit.
- [ ] **AC-7:** Error: when `/pr`'s `cmd_complete` invocation exits non-zero (e.g., spec file missing, metadata malformed), `/pr` stops and surfaces the error — does not silently proceed to push.
- [ ] **AC-8:** After a full cycle (`activate <id> → /pr → merge → land`), `docs-check.sh list-specs` reports the feature as `Complete` and zero specs `In Progress`.

## Affected Files

| File | Change |
|------|--------|
| `.ccanvil/scripts/docs-check.sh` | Modified — add safety-net scan in `cmd_land`; bypass via `ALLOW_MAIN=1` |
| `.claude/commands/pr.md` | Modified — replace step 7 (manual `rm + commit`) with a `cmd_complete <feature-id>` invocation path; preserve fallback for no-active-spec |
| `.ccanvil/guide/lifecycle.md` | Modified — document the new merge → complete auto-transition |
| `hub/tests/feature-lifecycle.bats` | New tests — primary path, safety-net path, no-active-spec path, non-claude-branch skip |

## Dependencies

- **Requires:** `cmd_complete` (exists), `cmd_land` (exists), `ALLOW_MAIN=1` bypass pattern (documented in `protect-main.sh`).
- **Blocked by:** nothing.

## Out of Scope

- Retroactive transition for branches merged before this lands — user runs `docs-check.sh complete <id>` manually once.
- Transitioning specs unrelated to the landed branch — only the feature_id matching `$branch` tail segment is touched.
- Multi-spec concurrency — `cmd_activate` already enforces "one In Progress at a time."
- GitHub webhook / merge-event listeners — out of scope; we hook on `/pr` and `cmd_land` only.
- A `--skip-complete` flag on `/pr` — defer until a real use case surfaces.

## Implementation Notes

- `cmd_complete` already does status update + `rm` of lifecycle docs + commit + `gh pr ready`. The `/pr` skill just needs to call it with the right feature_id.
- Feature-id parsing in `cmd_land`: capture `$branch` (current branch name) BEFORE the checkout-main step. Tail segment via parameter expansion (`${branch##*/}`). Sanity check: require prefix `claude/` — otherwise skip safety net.
- The `ALLOW_MAIN=1` pattern is already used for `/stasis` and `idea-migration` commits (see `protect-main.sh`). Reuse the exact same invocation shape.
- Scope the safety-net scan to specs whose `feature_id` equals the parsed branch tail AND whose `status == "In Progress"`. Do not touch Draft, Ready, or Complete specs.
- Tests should cover: normal `/pr` path (spec completes on branch, merges, `cmd_land` finds nothing to do), `/pr` skipped (spec still In Progress on main, `cmd_land` fires safety net), non-claude branch (safety net silently skipped), malformed spec (cmd_complete errors, `/pr` halts).

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
