# Implementation Plan: Fix BSD mktemp template in /permissions-review skill prose

> Feature: bts-160-fix-bsd-mktemp-template
> Work: linear:BTS-160
> Created: 1777139900
> Spec hash: 297677eb
> Based on: docs/spec.md

## Objective

Replace three BSD-incompatible `mktemp` invocations in `.claude/commands/permissions-review.md` with `mktemp -t <prefix>` form so concurrent skill invocations don't collide on the literal filename `XXXXXX.<ext>`.

## Sequence

### Step 1: Fix the two visible `mktemp` invocations in step 1 (Gather state)

- **Test:** None automated (skill prose has no test surface). Pre-edit verification: `grep -n "mktemp" .claude/commands/permissions-review.md` shows three matches (lines 10–11 + the line 17 narrative reference to `mktemp`). Post-edit verification: lines 10–11 use the `-t <prefix>` form; no `XXXXXX.<ext>` mid-template patterns remain.
- **Implement:** In `.claude/commands/permissions-review.md`, replace:
  ```bash
  PR_PROMOTE=$(mktemp /tmp/pr-promote.XXXXXX.json)
  PR_CHECK=$(mktemp /tmp/pr-check.XXXXXX.json)
  ```
  with:
  ```bash
  PR_PROMOTE=$(mktemp -t pr-promote)
  PR_CHECK=$(mktemp -t pr-check)
  ```
- **Files:** `.claude/commands/permissions-review.md` (lines 10–11)
- **Verify:** `grep -E 'mktemp.*XXXXXX' .claude/commands/permissions-review.md` returns no matches.

### Step 2: Make the decisions tmpfile creation explicit in step 5 (Dispatch)

- **Test:** Pre-edit: step 5 prose says "Write the JSONL buffer to a tmpfile" without specifying how. The implicit gap was where Claude improvised `mktemp /tmp/pr-decisions.XXXXXX.jsonl` during the BTS-149 walk. Post-edit: step 5 explicitly creates the tmpfile via `mktemp -t pr-decisions` before the dispatch call, and references the resulting variable in the dispatch.
- **Implement:** Update `.claude/commands/permissions-review.md` step 5 ("Dispatch") to start with:
  ```bash
  DECISIONS=$(mktemp -t pr-decisions)
  ```
  and update the prose to write the JSONL buffer to `$DECISIONS`, then:
  ```bash
  bash .ccanvil/scripts/permissions-audit.sh apply --decisions "$DECISIONS"
  ```
- **Files:** `.claude/commands/permissions-review.md` (step 5 / Dispatch section, lines ~62–74)
- **Verify:** Step 5 prose contains the literal `mktemp -t pr-decisions` invocation. `grep -E 'mktemp.*XXXXXX' .claude/commands/permissions-review.md` still returns no matches.

### Step 3: Update step 6 (Cleanup) to reference all three tmpfile variables

- **Test:** Pre-edit: step 6 reads `rm "$PR_PROMOTE" "$PR_CHECK" <decisions-tmpfile>` — the decisions variable is a placeholder, not a real var name. Post-edit: cleanup references `$DECISIONS` literally.
- **Implement:** Replace the line:
  ```bash
  rm "$PR_PROMOTE" "$PR_CHECK" <decisions-tmpfile>
  ```
  with:
  ```bash
  rm "$PR_PROMOTE" "$PR_CHECK" "$DECISIONS"
  ```
- **Files:** `.claude/commands/permissions-review.md` (step 6, line ~78)
- **Verify:** `grep "rm \"\$PR_PROMOTE\"" .claude/commands/permissions-review.md` shows the corrected three-arg form.

### Step 4: Manual verification (AC-5, AC-6)

- **Test:** No automated test. Open `.claude/commands/permissions-review.md` and read sections 1, 5, 6 to confirm the three mktemp calls and the cleanup line are coherent.
- **Implement:** No code change. Inspection only.
- **Files:** `.claude/commands/permissions-review.md` (read-only)
- **Verify:** Run `bash -c 'PR_PROMOTE=$(mktemp -t pr-promote); PR_CHECK=$(mktemp -t pr-check); DECISIONS=$(mktemp -t pr-decisions); echo $PR_PROMOTE; echo $PR_CHECK; echo $DECISIONS; rm "$PR_PROMOTE" "$PR_CHECK" "$DECISIONS"'` to confirm three unique non-literal paths in `$TMPDIR` (proves the new pattern works on this machine's BSD `mktemp`).

### Step 5: Documentation check (preset infrastructure modification)

- **Test:** `grep -n "mktemp\|/permissions-review" .ccanvil/guide/command-reference.md` — confirm the guide references the skill at the behavior level only (lines 9, 57) and does not document the internal mktemp mechanism.
- **Implement:** No edit needed. The guide describes `/permissions-review` at the contract level (idempotent, walks rows, dispatches via `apply --decisions`) — none of which changes with this fix. The mktemp form is an internal detail not documented in the guide.
- **Files:** `.ccanvil/guide/command-reference.md` (read-only confirmation)
- **Verify:** Step 5 of plan template (preset infrastructure docs update) is satisfied by the no-change finding. Note in the commit message that the guide was checked and confirmed unaffected.

## Risks

- **BSD vs GNU `mktemp -t` semantics differ on path resolution.** BSD writes to `$TMPDIR` (defaults to `/tmp`); GNU writes to a relative path under `$TMPDIR` if it's set, otherwise `/tmp`. Both behaviors are acceptable for the skill's use case (we just need unique tmpfiles). If `$TMPDIR` is unset, both fall back to `/tmp` on macOS and Linux. No mitigation needed.
- **No regression test guarding against re-introduction of the `XXXXXX.<ext>` pattern.** A future skill author could re-introduce the bug. Mitigation: out of scope for BTS-160, but worth a follow-up idea capture if the pattern recurs (a bats-style lint scanning skill prose for BSD-incompatible mktemp templates).
- **Skill prose changes don't have CI test coverage.** Verification is manual per the spec's AC-5/AC-6. Acceptable risk for a prose-only edit.

## Definition of Done

- [ ] All 6 acceptance criteria from `docs/spec.md` pass.
- [ ] All existing bats tests still pass (`bash .ccanvil/scripts/bats-report.sh --parallel`) — sanity check that no script-level changes leaked in.
- [ ] No type errors (N/A for bash skill prose).
- [ ] Code reviewed (run `/review`).
- [ ] `grep -E 'mktemp.*XXXXXX' .claude/commands/permissions-review.md` returns zero matches.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
