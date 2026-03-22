# Feature: Determinism Enforcement

> Feature: determinism-enforcement
> Created: 1774211321
> Status: Draft

## Summary

Make the end-of-session determinism review mandatory, performed in warm context during checkpoint (before `/clear`), and backed by a safety-net script for post-hoc detection. The warm-context review is the primary mechanism because Claude has full session awareness — every manual step, every improvisation, every workaround. The script catches what the warm review missed. `/catchup` surfaces both.

## Job To Be Done

**When** I checkpoint my work before clearing context,
**I want to** be forced to review what was stochastic while I still have full session awareness,
**So that** deterministic improvements are captured in warm context (where signal is richest) and survive into the next session.

## Acceptance Criteria

### Part 1: Warm-context review during checkpoint (primary mechanism)
- [ ] **AC-1:** The checkpoint template (`docs/templates/checkpoint.md`) has a required `## Determinism Review` section with structured fields: `operations_reviewed: [count]`, `candidates_found: [count]`, and a bulleted list format.
- [ ] **AC-2:** The workflow rule (`workflow.md`) instructs Claude to fill the Determinism Review section at every checkpoint, **before** suggesting `/clear`. The review must happen in warm context — Claude has full session awareness and can identify operations it performed that should be scripted. Even if no candidates are found, the entry must read "No candidates this session."
- [ ] **AC-3:** The workflow rule specifies the review checklist Claude must walk through: (a) Did I run manual `cp`, `jq`, `shasum`, or `git -C` commands that a script should handle? (b) Did I improvise a multi-step sequence that could be a single script call? (c) Did I work around a missing feature in a script? (d) Did I perform any operation more than once that should be automated?
- [ ] **AC-4:** `docs-check.sh validate` reports `missing-determinism-review` when checkpoint.md exists but has no `## Determinism Review` section (or the section is empty/placeholder-only).

### Part 2: Safety-net script (post-hoc detection)
- [ ] **AC-5:** `docs-check.sh audit-session` scans `git diff <last-checkpoint-commit>..HEAD` for patterns indicating stochastic operations: manual `cp` commands, inline `jq` pipelines, `shasum`/`sha256sum` calls, `git -C` commands, and multi-step file manipulation sequences.
- [ ] **AC-6:** `audit-session` outputs JSON: `{patterns_found: [{pattern, file, line, context}], summary: {total, by_category}}`.
- [ ] **AC-7:** `audit-session` accepts an optional `--since <commit>` flag. Without it, defaults to the commit tagged in checkpoint.md metadata or the last 10 commits.
- [ ] **AC-8:** `audit-session` has zero false positives on scaffold scripts themselves (scaffold-sync.sh, manifest-check.sh, docs-check.sh are allowlisted — they're *supposed* to run these commands).
- [ ] **AC-9:** `audit-session` scans commit messages (not just diffs) for phrases like "manually ran", "had to", "workaround", which indicate improvised steps.

### Part 3: /catchup integration (cross-session continuity)
- [ ] **AC-10:** `/catchup` reads the `## Determinism Review` section from the previous checkpoint and, if candidates were found, displays them under an "Outstanding determinism improvements" heading before the regular summary.
- [ ] **AC-11:** `/catchup` runs `docs-check.sh audit-session --since <checkpoint-commit>` and appends any new findings to the report (captures stochastic operations that happened between the checkpoint and now).

## Affected Files

| File | Change |
|------|--------|
| `docs/templates/checkpoint.md` | Modified — add required Determinism Review section with checklist |
| `scripts/docs-check.sh` | Modified — add `audit-session` subcommand, extend `validate` for missing review detection |
| `tests/docs-check.bats` | Modified — new tests for audit-session and validate extension |
| `.claude/rules/workflow.md` | Modified — checkpoint flow: write content → warm-context determinism review → then suggest /clear |
| `.claude/rules/self-review.md` | Modified — reference the mandatory checkpoint section and review checklist |
| `.claude/commands/catchup.md` | Modified — surface outstanding determinism items + run audit-session |
| `README.md` | Modified — document audit-session in scripts manifest |
| `GUIDE.md` | Modified — add audit-session to command reference |

## Dependencies

- **Requires:** `docs-check.sh` (done), lifecycle metadata in checkpoint (done)
- **Blocked by:** Nothing

## Out of Scope

- Auto-fixing stochastic operations (the script reports, humans decide)
- Blocking commits that have stochastic patterns (too aggressive — many are legitimate)
- Scanning non-git-tracked operations (terminal history, etc.)
- Full `/scaffold-audit` integration (that's a separate, heavier analysis)

## Implementation Notes

- **Warm context is the primary signal.** The audit-session script is a safety net, not the main detector. Claude in warm context knows it ran `cp` manually or improvised a workaround — no regex can match that fidelity. The script catches things Claude forgot to flag or didn't recognize as stochastic.
- **Checkpoint flow order matters.** The workflow rule must specify: (1) write checkpoint content (accomplished, state, next steps), (2) perform determinism review checklist in warm context, (3) write the Determinism Review section, (4) commit, (5) *then* suggest `/clear`. The review must happen before context is lost.
- **Pattern detection (safety net):** Use `git diff --unified=0` to get changed lines only, then grep for patterns. Categories: `cp ` (file copy), `jq ` (JSON manipulation), `shasum|sha256sum` (hash computation), `git -C` (cross-repo git), `curl|wget` (network fetches that could be scripted). Each pattern has an allowlist of files where it's expected.
- **Allowlist:** `scripts/*.sh` files are allowlisted by default — they're the deterministic implementations. Only flag these patterns in commit messages, slash command outputs, or non-script files.
- **Checkpoint commit detection:** Read checkpoint.md metadata for the commit hash, or fall back to `git log --grep="checkpoint" -1 --format=%H`.
- **The "no candidates" case is important:** Requiring "No candidates this session" when nothing is found normalizes the review. It's the equivalent of a pilot's checklist — you confirm you checked, not just that you found something.
