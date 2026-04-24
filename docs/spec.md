# Feature: Land Post-Merge Branch Recovery

> Feature: bts-138-land-post-merge-branch-recovery
> Work: linear:BTS-138
> Created: 1777063437
> Status: In Progress

## Summary

`docs-check.sh land` currently emits the `AUTO-CLOSE:` marker only when invoked from the feature branch. `gh pr merge --delete-branch` switches local HEAD to `main` and deletes the feature branch before `/land` runs, so the `branch == main` path fast-forwards main but never calls `cmd_auto_close_emit`. The Linear ticket stays open, and Claude must manually invoke `auto-close-emit <branch>`. This feature recovers the landed branch from the most recent squash-merge commit's `(#<PR>)` suffix via `gh pr view`, then feeds it to the existing emitter — closing the gap without rewriting the decision tree.

## Job To Be Done

**When** `/land` runs on main after `gh pr merge --delete-branch`,
**I want to** have the linked Linear issue auto-close without manual `auto-close-emit`,
**So that** the feature-lifecycle → Linear sync is whole and the determinism-review candidate stops recurring.

## Acceptance Criteria

Each criterion is independently testable. Binary pass/fail.

- [ ] **AC-1:** Given `cmd_land` is invoked with `HEAD == main` and the last commit has subject matching `… (#<N>)`, when `gh pr view <N> --json headRefName` returns `claude/feat/<slug>`, then `cmd_land` emits `AUTO-CLOSE: {"provider":"linear","id":"<id>","role":"done"}` on stdout (via the existing `cmd_auto_close_emit` code path).
- [ ] **AC-2:** Given the last commit on `main` is `docs: stasis …` (session-stasis), when `cmd_land` runs on main, then it inspects `HEAD~1` instead of `HEAD` to find the squash-merge commit. If `HEAD~1` also isn't a squash-merge, it skips emission (AC-5).
- [ ] **AC-3:** Given the last commit on main has no `(#<N>)` suffix (non-squash merge, direct push, etc.), when `cmd_land` runs on main, then it emits `WARN: land on main — could not recover PR number from last commit` on stderr, exits 0, and does NOT emit any `AUTO-CLOSE:` marker.
- [ ] **AC-4:** Given `gh` is offline or the PR lookup fails, when `cmd_land` runs on main after parsing a `(#<N>)` suffix, then it emits `WARN: land on main — could not recover landed branch via gh (reason)` on stderr, exits 0, and does NOT emit any `AUTO-CLOSE:` marker.
- [ ] **AC-5:** Given the recovered branch name does NOT match `^claude/[^/]+/.+$`, when `cmd_land` runs on main, then it delegates to `cmd_auto_close_emit` which already handles this case (emits `auto-close: no feature-id detected …`, exits 0) — no new code path needed. Test verifies the existing behavior still holds when reached via the new path.
- [ ] **AC-6:** Given the recovered branch maps to a spec whose `Work:` is `local:<uid>` or a non-Linear provider, when `cmd_land` runs on main, then `cmd_auto_close_emit` logs the skip message (existing behavior) and no AUTO-CLOSE marker is emitted. Test verifies existing branches of the decision tree still fire correctly when reached via the main-path recovery.
- [ ] **AC-7:** The existing on-branch path (branch ≠ main) is unchanged. A bats test that was passing before this change MUST still pass after — no regressions in BTS-119's test surface.
- [ ] **AC-8:** `gh` is not invoked when `gh` binary is missing from PATH. `cmd_land` on main degrades to `WARN: land on main — gh unavailable, skipping PR recovery` and exits 0.
- [ ] **AC-9:** The recovery logic is isolated to a new helper `cmd_land_recover_branch` (or inlined with a clear comment) so tests can exercise it without standing up a full merge workflow — bats cases seed a fake merge commit in a test repo and stub `gh pr view` via `PATH` override.
- [ ] **AC-10:** Dogfood-close: the `/land` cycle that ships this fix must itself auto-close BTS-138 in Linear without a manual `auto-close-emit` invocation. If the ship requires manual intervention, the fix is incomplete.

## Affected Files

| File | Change |
|------|--------|
| `.ccanvil/scripts/docs-check.sh` | Modified — extend `cmd_land`'s `branch == main` path to recover + dispatch |
| `hub/tests/land-post-merge-recovery.bats` | New test file — 9 cases covering ACs 1-9 |
| `hub/tests/land.bats` | Possibly modified — audit existing cases to ensure AC-7 (no regressions) |
| `.ccanvil/guide/command-reference.md` | Modified — update `land` command docs to note post-merge-on-main behavior |

## Dependencies

- **Requires:** BTS-119 (shipped — `cmd_auto_close_emit` exists and handles all provider/spec decisions). BTS-128 (shipped — `ticket.transition` dispatcher in `/land` skill) indirectly consumes the emitted marker.
- **Blocked by:** nothing.

## Out of Scope

- Non-squash merges (merge commits, rebase-merges) — GitHub squash-merge `(#<PR>)` is the canonical ccanvil path.
- Non-GitHub providers (GitLab, Bitbucket). `gh` is the only supported CLI for PR-number → branch recovery.
- Changing the on-branch `cmd_land` path or the `cmd_auto_close_emit` decision tree — this is strictly additive.
- Triage stateId regression observed during this session's capture (BTS-138 landed in Backlog despite `stateId`). Will be triaged separately if still an issue.

## Implementation Notes

- **Helper shape:** extract `cmd_land_recover_branch` (private-style helper). Takes no args; returns branch name on stdout or empty on failure. Keep WARN messages on stderr so bats `$output` is clean for status-only assertions.
- **Commit inspection:** use `git log -1 --format=%s` for subject; regex `\(#([0-9]+)\)$` captures the PR number. If subject matches `^docs: stasis `, fall through to `git log -1 --skip=1 --format=%s`.
- **`gh pr view <N> --json headRefName -q .headRefName`** is the minimal query. Exit non-zero ⇒ WARN + skip.
- **Delegation, not duplication:** once the branch is recovered, call `cmd_auto_close_emit "$recovered_branch"` — it already handles the `^claude/[^/]+/(.+)$` match, the spec-file load, the `Work:` extraction, and the provider dispatch. This is the dogfood: reuse the BTS-119 primitive instead of re-implementing.
- **Test isolation:** seed a bare repo with a synthetic squash-merge commit (empty tree is fine), stub `gh` by prepending a test `PATH` directory containing an executable shim that reads `$1` and writes expected JSON. Follows the pattern established in `hub/tests/helpers/`.
- **Same AC-7 regression audit as BTS-122/113:** run the full bats suite before and after — count must stay green, on-branch path tests must still pass unchanged.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
