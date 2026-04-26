# Implementation Plan: derive-pr-title substrate primitive

> Feature: bts-181-derive-pr-title
> Work: linear:BTS-181
> Created: 1777219094
> Spec hash: de764c3f
> Based on: docs/spec.md

## Objective

Factor PR-title derivation into one `cmd_derive_pr_title` primitive used by both `cmd_activate` and `cmd_assert_pr_title`, with deterministic truncation (first period, then 80-char cap on suffix) so verbose Summaries no longer require manual `gh pr edit`.

## Sequence

### Step 1: Bats fixtures + AC-1 (happy path)
- **Test:** `derive-pr-title "<spec>"` on a spec whose Summary is `Short feature line.` emits `feat(<feature-id>): Short feature line` (period stripped per AC-3).
- **Implement:** add `cmd_derive_pr_title` in docs-check.sh — read `> Feature:` and the first non-blank Summary line via the same `sed` already used; apply truncation; emit `feat(<id>): <line>`.
- **Files:** `hub/tests/derive-pr-title.bats` (new), `.ccanvil/scripts/docs-check.sh` (add function + dispatcher case).
- **Verify:** new test passes; existing suite stays green.

### Step 2: AC-2 (≤80 chars, no period → verbatim)
- **Test:** Summary `Short bare line` (15 chars, no period) → emits `feat(<id>): Short bare line` unchanged.
- **Implement:** truncation logic: only apply period-strip when a period exists; only apply 80-char cap when the line exceeds 80.
- **Files:** docs-check.sh, derive-pr-title.bats.

### Step 3: AC-3 (period-strip)
- **Test:** Summary `Add foo. Bar baz.` → `feat(<id>): Add foo`.
- **Implement:** covered by Step 1; add explicit test.
- **Files:** derive-pr-title.bats.

### Step 4: AC-4 (80-char truncation, no period in first 80)
- **Test:** Summary line of 120 chars with no period anywhere → suffix is exactly 80 chars, no trailing whitespace.
- **Implement:** after period-strip (no-op when none), `${suffix:0:80}` then trim trailing whitespace via parameter expansion.
- **Files:** docs-check.sh, derive-pr-title.bats.

### Step 5: AC-5 (empty Summary fallback)
- **Test:** spec with empty Summary section → emits `feat(<id>): activate feature`.
- **Implement:** preserve `${first_line:-activate feature}` semantics inside the new primitive.
- **Files:** docs-check.sh, derive-pr-title.bats.

### Step 6: AC-6 (missing/bad input)
- **Test:** `derive-pr-title` with no args → non-zero exit, error to stderr; with non-existent file → non-zero exit, error to stderr; both: empty stdout.
- **Implement:** arg validation at function entry; print `ERROR: ...` to stderr, return 1.
- **Files:** docs-check.sh, derive-pr-title.bats.

### Step 7: AC-7 — refactor `cmd_activate`
- **Test:** existing `hub/tests/` suite stays green (drift caught by AC-9 below + the indirect coverage of activate behavior in existing tests).
- **Implement:** replace lines 982–984 (the inline `sed` + `pr_title=` assignment) with a single call to `cmd_derive_pr_title "$spec_file"`. Capture stdout into `pr_title`.
- **Files:** docs-check.sh.

### Step 8: AC-8 — refactor `cmd_assert_pr_title`
- **Test:** `hub/tests/assert-pr-title.bats` stays green; expected_title is now produced by the primitive.
- **Implement:** replace lines 2444–2447 with call to `cmd_derive_pr_title "$spec_file"`. Capture into `expected_title`.
- **Files:** docs-check.sh.
- **Note:** the existing AC-1 test in assert-pr-title.bats uses `Test feature first line.` — period-strip means expected becomes `Test feature first line` (no period). Update the stub title in those assertions to match. This is a behavioral change consistent with AC-3.

### Step 9: AC-9 — drift-guard
- **Test:** new bats asserts `cmd_activate` and `cmd_assert_pr_title` no longer contain inline `sed -n '/^## Summary$/...'` extractions. Use `grep -c 'sed -n .\^## Summary' .ccanvil/scripts/docs-check.sh` and assert count == 0 (or == 1 if the primitive itself uses it — adjust to match implementation).
- **Implement:** drift-guard test in derive-pr-title.bats.
- **Files:** derive-pr-title.bats.

### Step 10: Full-suite verification + commit
- **Verify:** `bash .ccanvil/scripts/bats-report.sh --parallel`; expect 1466 + new tests, all green.
- **Commit:** one logical commit `feat(bts-181-derive-pr-title): factor + truncate PR-title derivation`.

## Risks

- **Behavioral shift in existing PR titles.** Period-strip means `Test feature first line.` becomes `Test feature first line` — existing assert-pr-title tests have to be updated. This is intentional per AC-3 but the test changes need careful audit (search for any string containing a literal period inside an assertion).
- **`cmd_assert_pr_title`'s prefix-match logic** uses `feat(${feature_id_meta}):` as the matching prefix — that's unchanged. The suffix-comparison stays loose. But the `expected_title` shown in the diagnostic output now reflects the truncated form. Acceptable.
- **`activate`'s call site already passes a fallback** via `${first_line:-activate feature}`. The new primitive must preserve that fallback even when the spec has an empty Summary (AC-5).

## Definition of Done

- [ ] All 9 ACs pass
- [ ] All existing tests still pass (no behavioral regressions outside the documented period-strip change)
- [ ] No type errors (n/a — bash)
- [ ] /review skipped per `feedback_skip_review_on_trivial_diffs` (substrate primitive + drift-guards in place; no logic complexity beyond what tests catch). Re-evaluate if implementation reveals branching.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
