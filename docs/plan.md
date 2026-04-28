# Implementation Plan: BTS-232 — /recall carry-forward determinism candidates

> Feature: bts-232-recall-carry-forward-determinism
> Work: linear:BTS-232
> Created: 1777334000
> Spec hash: bc3f3ba4
> Based on: docs/spec.md

## Objective

Add `cmd_stasis_carry_forward` substrate primitive + `/recall` skill prose update so the briefing surfaces determinism candidates from the prior stasis that were never dual-captured to Linear.

## Sequence

### Step 1: Bats fixture + RED — `cmd_stasis_carry_forward` exists, all-matched returns empty
- **Test:** AC-1 happy path. Fixture: stasis content with `## Determinism Review` listing 2 candidates (one bolded-shape, one backtick-shape). Issue listing JSON contains matching `Determinism: <slug>` entries for both. Assert `{count_total: 2, count_carry_forward: 0, candidates[*].has_idea: true}`.
- **Implement:** Skeleton of `cmd_stasis_carry_forward` returning `{candidates: [], count_total: 0, count_carry_forward: 0}` only — test SHOULD fail because count_total != 2.
- **Files:** `hub/tests/stasis-carry-forward.bats` (new), `.ccanvil/scripts/docs-check.sh` (skeleton fn + dispatch entry).
- **Verify:** Run the new bats — confirm RED.

### Step 2: GREEN Step 1 — implement parsing + matching logic
- **Test:** AC-1 from Step 1.
- **Implement:** Full `cmd_stasis_carry_forward`:
  1. Resolve `--project-dir`, `--stasis-content -` (stdin override), `--input-json <path>` (idea listing override).
  2. Read stasis: stdin if `--stasis-content -`, else `cmd_artifact_read --kind stasis --stasis-kind session` (fallback `--stasis-kind feature` if empty). If still empty → emit `{candidates: [], count_total: 0, count_carry_forward: 0, note: "no prior stasis"}`.
  3. Extract `## Determinism Review` section: from header to next `## ` or EOF. If absent → empty result.
  4. Parse bullets: lines beginning with `* ` or `- `. Skip lines that are metadata-shaped (`* operations_reviewed:`, `* candidates_found:`).
  5. For each bullet, extract slug:
     - If bullet body starts with `**` → match leading `**...**` (greedy) — that's the slug.
     - Else if starts with `` ` `` → take the first backticked token + any subsequent backticked tokens joined by ` → ` (handles session 7 shape `` `pr-cleanup` → `gh pr edit --title` ``) until first `:` or first non-backtick text.
     - Else → take leading text up to first `:` or first 60 chars, whichever shorter.
  6. Read idea listing: from `--input-json <path>` if provided, else `eval "$(operations.sh resolve idea.list | jq -r '.invocation.command')"`. Listing is a JSON array `[{id, title, status}, ...]`.
  7. For each candidate slug, case-insensitive substring match against `title` field looking for `Determinism: ` prefix + slug substring. Set `has_idea: true|false` and `idea_id: <id>|null`.
  8. Compute `count_total = len(candidates)`, `count_carry_forward = sum(has_idea == false)`.
  9. Emit JSON.
- **Files:** `.ccanvil/scripts/docs-check.sh`.
- **Verify:** AC-1 test passes. Confirm with `run bash $SCRIPT stasis-carry-forward --stasis-content - --input-json $FIXTURE < $STASIS`.

### Step 3: AC-2 slug-shape tolerance tests
- **Test:** Two new bats tests:
  - **AC-2a:** Stasis with bolded-shape bullet (`**foo-bar**: ...`), idea listing has `Determinism: foo-bar`. Match → `has_idea: true`.
  - **AC-2b:** Stasis with backtick-shape (` `foo` → `bar` `), idea listing has `Determinism: foo` substring. Match → `has_idea: true`.
- **Implement:** Already covered by Step 2 logic if correct.
- **Files:** `hub/tests/stasis-carry-forward.bats`.
- **Verify:** Both pass.

### Step 4: AC-4 empty-state + AC-5 no-prior-stasis tests
- **Test:** Two new bats tests:
  - **AC-4:** Stasis with `## Determinism Review` containing only `No candidates this session.` → `{count_total: 0, count_carry_forward: 0}`, no error.
  - **AC-5:** No stasis at all (don't write `docs/stasis.md`, don't pass `--stasis-content`). Without stdin, the substrate calls `artifact-read` which returns empty for the test project — emit `{candidates: [], count_total: 0, count_carry_forward: 0, note: "no prior stasis"}`. Use a local-routed test project-dir so artifact-read returns gracefully.
- **Implement:** Empty section + missing stasis branches in cmd_stasis_carry_forward.
- **Files:** `hub/tests/stasis-carry-forward.bats`.
- **Verify:** Both pass.

### Step 5: Mixed-state test (some matched, some not)
- **Test:** AC-1/AC-3 mixed scenario. Stasis with 3 candidates; idea listing matches 1 of 3. Assert `count_carry_forward: 2` and the carried slugs surface in `candidates[?].has_idea == false`.
- **Implement:** No new code; verifies the count + filter logic.
- **Files:** `hub/tests/stasis-carry-forward.bats`.
- **Verify:** Passes.

### Step 6: AC-3 — `/recall` skill prose update + drift-guard
- **Test:** Drift-guard test that asserts `.claude/skills/recall/SKILL.md` references BTS-232 and contains the new step calling `stasis-carry-forward`. Also asserts the briefing block lists `**Carry-forward determinism candidates:**` heading.
- **Implement:** Edit `.claude/skills/recall/SKILL.md`:
  - Insert new step between current step 6 (read determinism review section) and step 6a (sessions-list) — call the new step "6b" or fold into 6.
  - Step body: resolve + dispatch `stasis-carry-forward`, capture `count_carry_forward`.
  - In Briefing block: add bullet `- **Carry-forward determinism candidates:** (BTS-232) — when `count_carry_forward > 0`, render under literal heading `**Carry-forward determinism candidates:**` with one bullet per `candidates[?has_idea==false].slug`. Silent when count is 0.
- **Files:** `.claude/skills/recall/SKILL.md`, `hub/tests/stasis-carry-forward.bats` (drift test).
- **Verify:** Drift-guard passes; lint check on SKILL.md grammar passes.

### Step 7: Drift-guard for substrate
- **Test:** `drift: BTS-232 referenced inline in docs-check.sh`.
- **Implement:** Add inline comment in `cmd_stasis_carry_forward` referencing BTS-232.
- **Files:** `.ccanvil/scripts/docs-check.sh`.
- **Verify:** Drift test passes.

### Step 8: Full suite green
- **Test:** Run `bash .ccanvil/scripts/bats-report.sh --parallel`.
- **Implement:** Fix any regressions surfaced.
- **Files:** As needed.
- **Verify:** PASS/FAIL/TOTAL — total >= 1787 + 6 = 1793. All green.

## Risks

- **Slug extraction over-matches** when a candidate body coincidentally contains "Determinism: <slug>" substring matching another candidate's slug. Mitigation: substring-match is intentionally permissive — false positives mean we DON'T surface a carry-forward when one exists, which is the safe direction (under-surface carry-forwards rather than nag operator with phantoms). Spec accepts this trade-off in AC-2.
- **`artifact-read` on stasis-bearing nodes that are mid-feature** could return the feature-kind stasis instead of session-kind. The skill prose for /recall currently uses session-kind first. Mitigation: try session-kind first, fall back to feature-kind.
- **No live-API gate flagged** — the substrate uses `LINEAR_QUERY_OVERRIDE` for tests (BTS-203 pattern); production path goes through `operations.sh resolve idea.list` which already proves the contract. No new live contract introduced.

## Definition of Done

- [ ] All 7 ACs from spec pass (5 substrate tests + drift + suite green)
- [ ] All existing tests still pass (1787 baseline → 1793+ total)
- [ ] Drift-guards reference BTS-232 in `docs-check.sh` and `SKILL.md`
- [ ] Code reviewed (run `/review`)

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
