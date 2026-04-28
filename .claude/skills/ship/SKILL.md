---
name: ship
description: Finalize a draft PR — title-fix + mark ready + squash-merge + branch delete + ticket auto-close, all in one command. Run AFTER /pr.
---

Collapse the post-`/pr` ship sequence into one verb. `/pr` ends with the PR marked ready. `/ship <PR>` does everything else: title force-update, merge, branch delete, switch to main, close the linked Linear ticket. Idempotent — re-running on a merged PR is a no-op.

## Usage

- `/ship <PR-NUMBER>` — finalize the draft PR by number.

## Steps

1. **Validate the PR number arg.** If missing, STOP with: `/ship requires a PR number. Example: /ship 128`.
2. **Dispatch the substrate:**
   ```bash
   bash .ccanvil/scripts/docs-check.sh ship-finalize <PR> --project-dir .
   ```
   Capture stdout (JSON) and exit code.
3. **Render a one-line operator-readable summary** from the JSON:
   - On success: `Shipped PR #<N>: title=<updated|skipped> | merged=true | ticket=<closed|queued|n/a>`.
   - On idempotent already-merged: `PR #<N> already merged — no-op.`
   - On pre-merge failure: `FAILED at step=<step>: <error>`. Exit non-zero so the caller (operator) sees the error.
4. **Print the URL** if available from `gh pr view`.

## What the substrate does

The `ship-finalize` substrate (BTS-235) runs:

1. `gh pr view <N> --json state` — pre-flight; idempotent on `MERGED`.
2. `cmd_assert_pr_title <N>` — BTS-178 substrate; force-updates the title to `feat(<feature-id>): <subject>` if placeholder-shaped.
3. `gh pr ready <N>` — idempotent (already-ready returns success).
4. `gh pr merge <N> --squash --delete-branch` — squash-merges, deletes remote + local branch, switches HEAD to main.
5. `cmd_land` — fast-forwards local main; recovers landed branch via the BTS-138 squash-subject parse; emits `AUTO-CLOSE: {provider, id, role}` marker on stdout.
6. Parses the AUTO-CLOSE marker; dispatches `ticket.transition <id> done` via `operations.sh resolve` + eval. On dispatch failure, queues to `.ccanvil/ideas-pending.log` (BTS-119 pattern).

Output JSON: `{pr, pr_merged, branch_deleted, title_result, ticket_closed, errors}`.

## Rules

- `/ship` runs ONLY after `/pr` has marked the PR ready and committed lifecycle cleanup. Do not run `/ship` on a draft PR — the substrate handles `gh pr ready` automatically, but `/pr`'s archive transition + push must already have happened.
- `/ship` NEVER force-pushes, NEVER bypasses hooks, NEVER skips signing.
- The post-merge ticket-close NEVER fails the ship — ticket-close failures queue to `.ccanvil/ideas-pending.log` for `/idea sync` to replay later.
- On non-GitHub remotes, `/ship` is not applicable — operator runs `bash .ccanvil/scripts/docs-check.sh land --force` directly.

## Composition with the existing flow

| Phase | Today | With BTS-235 |
|------|-------|--------------|
| Pre-merge | `/pr` (commits + push + ready) | `/pr` (unchanged) |
| Title fix | manual `gh pr edit` or `assert-pr-title` | folded into `/ship` |
| Merge | manual `gh pr merge --squash --delete-branch` | folded into `/ship` |
| Land | manual `bash docs-check.sh land` (or skipped) | folded into `/ship` |
| Ticket close | manual `ticket.transition done` (often forgotten) | folded into `/ship` |

Saves 4 commands → 1 per ship. At ~5 ships per release, that's ~20 fewer manual steps.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
