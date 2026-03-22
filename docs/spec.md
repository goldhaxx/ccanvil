# Feature: Determinism Enforcement

> Feature: determinism-enforcement
> Created: 1774211321
> Status: Draft

## Summary

Make the end-of-session determinism review mandatory and partially automatable. Currently `self-review.md` asks Claude to "briefly assess" stochastic operations during checkpoints, but nothing enforces this — it's a judgment-based instruction that competes with ~150 others for attention. This feature adds a required checkpoint section, a script that scans for stochastic patterns, and `/catchup` integration to surface outstanding items.

## Job To Be Done

**When** I end a session and checkpoint my work,
**I want to** be forced to assess what was stochastic and have tooling surface obvious candidates,
**So that** deterministic improvements accumulate across sessions instead of being forgotten under context pressure.

## Acceptance Criteria

### Part 1: Mandatory checkpoint section
- [ ] **AC-1:** The checkpoint template (`docs/templates/checkpoint.md`) has a required `## Determinism Review` section with structured fields: `operations_reviewed: [count]`, `candidates_found: [count]`, and a bulleted list format.
- [ ] **AC-2:** `docs-check.sh validate` reports `missing-determinism-review` when checkpoint.md exists but has no `## Determinism Review` section (or the section is empty).
- [ ] **AC-3:** The workflow rule (`workflow.md`) instructs Claude to fill the Determinism Review section at every checkpoint, even if the entry is "No candidates this session."

### Part 2: Deterministic session audit script
- [ ] **AC-4:** `docs-check.sh audit-session` scans `git diff <last-checkpoint-commit>..HEAD` for patterns indicating stochastic operations: manual `cp` commands, inline `jq` pipelines, `shasum`/`sha256sum` calls, `git -C` commands, and multi-step file manipulation sequences.
- [ ] **AC-5:** `audit-session` outputs JSON: `{patterns_found: [{pattern, file, line, context}], summary: {total, by_category}}`.
- [ ] **AC-6:** `audit-session` accepts an optional `--since <commit>` flag. Without it, defaults to the commit tagged in checkpoint.md metadata or the last 10 commits.
- [ ] **AC-7:** `audit-session` has zero false positives on scaffold scripts themselves (scaffold-sync.sh, manifest-check.sh, docs-check.sh are allowlisted — they're *supposed* to run these commands).
- [ ] **AC-8:** `audit-session` scans commit messages (not just diffs) for phrases like "manually ran", "had to", "workaround", which indicate improvised steps.

### Part 3: /catchup integration
- [ ] **AC-9:** `/catchup` reads the `## Determinism Review` section from the previous checkpoint and, if candidates were found, displays them under a "Outstanding determinism improvements" heading before the regular summary.
- [ ] **AC-10:** `/catchup` runs `docs-check.sh audit-session --since <checkpoint-commit>` and appends any new findings to the report (captures stochastic operations that happened between the checkpoint and now).

## Affected Files

| File | Change |
|------|--------|
| `docs/templates/checkpoint.md` | Modified — add required Determinism Review section |
| `scripts/docs-check.sh` | Modified — add `audit-session` subcommand, extend `validate` |
| `tests/docs-check.bats` | Modified — new tests for audit-session and validate extension |
| `.claude/rules/workflow.md` | Modified — checkpoint instructions for Determinism Review |
| `.claude/rules/self-review.md` | Modified — reference the new script and required section |
| `.claude/commands/catchup.md` | Modified — surface outstanding determinism items |
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

- **Pattern detection:** Use `git diff --unified=0` to get changed lines only, then grep for patterns. Categories: `cp ` (file copy), `jq ` (JSON manipulation), `shasum|sha256sum` (hash computation), `git -C` (cross-repo git), `curl|wget` (network fetches that could be scripted). Each pattern has an allowlist of files where it's expected.
- **Allowlist:** `scripts/*.sh` files are allowlisted by default — they're the deterministic implementations. Only flag these patterns in commit messages, slash command outputs, or non-script files.
- **Checkpoint commit detection:** Read checkpoint.md metadata for the commit hash, or fall back to `git log --grep="checkpoint" -1 --format=%H`.
- **The "no candidates" case is important:** Requiring "No candidates this session" when nothing is found normalizes the review. It's the equivalent of a pilot's checklist — you confirm you checked, not just that you found something.
