# Implementation Plan: stasis history directory + checkpoint cleanup

> Feature: bts-22-stasis-history-and-checkpoint-cleanup
> Work: linear:BTS-22
> Created: 1777220407
> Spec hash: 2ae52e60
> Based on: docs/spec.md

## Objective

Persist per-session stasis files in `docs/sessions/<epoch>-<feature_id>.md` so `/stasis` and `/recall` can read recent sessions without git archeology, while keeping all existing single-file lifecycle substrate (`docs/spec.md`, `docs/plan.md`, `docs/stasis.md`) untouched.

## Sequence

### Step 1: Bats scaffolding + AC-1 happy path
- **Test:** `archive-stasis` on a fixture project with `docs/stasis.md` containing `> Feature: x` and `> Last updated: 1700` writes `docs/sessions/1700-x.md` with byte-identical content; emits `{archived: true, path: "docs/sessions/1700-x.md"}`.
- **Implement:** add `cmd_archive_stasis` reading `> Feature:` and `> Last updated:` (fallback `> Created:`), copies via `cp`, emits JSON via `jq -n`. Add dispatcher case `archive-stasis) cmd_archive_stasis "$@" ;;`.
- **Files:** `hub/tests/stasis-history.bats` (new), `.ccanvil/scripts/docs-check.sh`.

### Step 2: AC-1 idempotency + AC-2 collision
- **Test (idempotency):** running `archive-stasis` twice with unchanged stasis emits `{archived: false, reason: "already-archived"}` on the second call, exit 0.
- **Test (collision):** modify `docs/sessions/<file>` to differ from current `docs/stasis.md` then re-run; non-zero exit with `{error: "collision", existing: "<path>"}`.
- **Implement:** before writing, if destination exists, hash both with `shasum -a 256` (or use the existing `_file_hash` helper if available); identical → idempotent return; different → collision error.

### Step 3: AC-3 missing/malformed input
- **Test:** missing `docs/stasis.md` → non-zero exit, stderr error. Stasis missing `> Feature:` or `> Last updated:` → non-zero exit, stderr error.
- **Implement:** input validation at function entry; clear error messages.

### Step 4: AC-7 sessions-list
- **Test:** create 3 fixture session files with epochs 1700, 1800, 1750; `sessions-list` emits JSON array sorted descending by epoch [1800, 1750, 1700] with `path`, `epoch`, `feature_id`, `kind` fields. `--limit 2` returns top 2.
- **Implement:** `cmd_sessions_list` — `find docs/sessions -maxdepth 1 -name '*.md'`, parse metadata via grep+sed (same pattern as `cmd_status`), sort by epoch desc, slice via head -N. JSON output via `jq -s`.
- **Files:** docs-check.sh, stasis-history.bats. Add dispatcher case.

### Step 5: AC-7 malformed-file resilience
- **Test:** create one valid + one malformed file; `sessions-list` returns the valid one and emits stderr warning for the malformed one. Exit 0.
- **Implement:** when metadata parse fails, log to stderr, skip the file; do not abort.

### Step 6: AC-6 validate isolation drift-guard
- **Test:** fresh fixture project with `aligned` triplet + populate `docs/sessions/` with stale-shaped files (wrong feature_id, mismatched hashes); assert `validate` still reports `aligned`. Drift-guard ensures sessions never affect lifecycle alignment.
- **Implement:** verify (don't change) — `cmd_validate` already references the live triplet by exact path, so this should pass without code changes. Add the drift-guard test to lock the contract.
- **Files:** `hub/tests/stasis-history-validate.bats` (new).

### Step 7: AC-5 cleanup-isolation drift-guards
- **Test:** grep `cmd_complete` and `cmd_land` function bodies for `docs/sessions` references; assert count == 0.
- **Implement:** verify (no code changes expected); test locks the contract.
- **Files:** stasis-history.bats.

### Step 8: AC-4 /stasis skill update + drift-guard
- **Implement:** edit `.claude/skills/stasis/SKILL.md` to add a step after the `git commit -m "docs: stasis ..."` step:
  ```bash
  ALLOW_MAIN=1 bash .ccanvil/scripts/docs-check.sh archive-stasis --project-dir .
  ALLOW_MAIN=1 git add docs/sessions/ && ALLOW_MAIN=1 git -c commit.gpgsign=false commit -m "chore(stasis-archive): persist <feature_id>"
  ```
- **Test:** drift-guard bats grep-checks `archive-stasis` appears in stasis SKILL.md AFTER the existing `commit -m "docs: stasis"` line.
- **Files:** stasis SKILL.md, stasis-history.bats.

### Step 9: AC-8 /recall skill update + fallback
- **Implement:** edit `.claude/skills/recall/SKILL.md` step 11 (the `git show HEAD~1:docs/stasis.md` step) to instead call:
  ```bash
  sessions=$(bash .ccanvil/scripts/docs-check.sh sessions-list --limit 3)
  if [[ $(echo "$sessions" | jq 'length') -gt 0 ]]; then
    # read each path
  else
    git show HEAD~1:docs/stasis.md  # fallback for fresh nodes
  fi
  ```
- **Test:** drift-guard bats grep-checks `sessions-list --limit 3` appears in recall SKILL.md (with fallback present).
- **Files:** recall SKILL.md, stasis-history.bats.

### Step 10: AC-9 checkpoint-cleanup drift-guard
- **Test:** grep all `.claude/skills/`, `.claude/commands/`, `.claude/rules/`, `.ccanvil/scripts/` for `docs/checkpoint.md` writes (`>` redirect, `Write` patterns, `cat >`); excluding `cmd_legacy_refs_scan` and `cmd_migrate_stasis_artifact` (whitelisted by name). Assert count of producers == 0.
- **Implement:** test only — no production code changes expected. If a producer is found, ship a fix in this same PR.
- **Files:** stasis-history.bats.

### Step 11: AC-10 CLAUDE.md + .gitkeep
- **Implement:** add `docs/sessions/             # Per-session stasis archive (committed history)` to CLAUDE.md `## Architecture`. Create `docs/sessions/.gitkeep` so the directory is committed.
- **Test:** drift-guard grep-checks the line in CLAUDE.md.
- **Files:** CLAUDE.md, docs/sessions/.gitkeep, stasis-history.bats.

### Step 12: Full-suite verification + dogfood + commit
- **Verify:** `bash .ccanvil/scripts/bats-report.sh --parallel`; expect 1475 + new tests, all green.
- **Dogfood:** run `archive-stasis` against the live `docs/stasis.md` (which exists from session-2026-04-26-determinism-trifecta-ship — wait, no, it was deleted in the BTS-181 pr-cleanup). May need to write a one-off live stasis to dogfood, OR rely on the bats fixture coverage. Skip if no live stasis is on disk.
- **Commit:** one logical commit `feat(bts-22): stasis history directory + checkpoint cleanup`.

## Risks

- **`docs/sessions/.gitkeep` and 100 future archive files.** Long term `docs/sessions/` will accumulate. Per BTS-22 spec scope, that's accepted. A future ticket can add a retention policy if it becomes unwieldy.
- **`/stasis` two-commit sequence.** The second commit (`chore(stasis-archive)`) is mechanical and may get noisy in `git log` filtered to `docs/`. Mitigation: clear commit message scope makes filtering trivial.
- **Recall fallback path.** First-stasis-on-fresh-node case must fall back to the git-show path. Tested in AC-8 drift-guard but not in a live fresh-node scenario; risk: low.
- **Test fixtures must not pollute `docs/sessions/`.** All bats setup() must use mktemp + isolated PROJECT directories so fixture session files never leak into the real `docs/sessions/`.

## Definition of Done

- [ ] All 10 ACs pass
- [ ] All existing tests still pass (1475 baseline preserved)
- [ ] No type errors (n/a — bash)
- [ ] /review skipped per `feedback_skip_review_on_trivial_diffs` — substrate primitives + drift-guards in place; no logic complexity beyond what tests catch. Re-evaluate if implementation reveals branching beyond plan.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
