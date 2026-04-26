# Implementation Plan: BTS-171 — Live-API validation rule

> Feature: bts-171-live-api-validation-rule
> Work: linear:BTS-171
> Created: 1777173900
> Spec hash: e0fb245f
> Based on: docs/spec.md

## Objective

Encode the recurring "live-API contract bugs slip past stub-only tests" pattern as durable substrate: a new section in `.claude/rules/tdd.md`, a risk-language instruction in `.claude/commands/plan.md`, a self-review flag-list bullet, a drift-guard test, and a one-line guide cross-reference.

## Sequence

### Step 1: Red — drift-guard test for tdd.md content

- **Test:** New `hub/tests/live-api-validation-rule.bats` with 2 assertions: (a) `.claude/rules/tdd.md` contains the literal phrase `live-API` somewhere in the hub-managed section, (b) tdd.md references at least one prior-incident anchor (`BTS-115` or `BTS-170`).
- **Implement:** Test-only commit. Tests fail because the rule isn't there yet.
- **Files:** `hub/tests/live-api-validation-rule.bats` (new).
- **Verify:** `bats hub/tests/live-api-validation-rule.bats` — both assertions fail.

### Step 2: Green — add the `## Live-API validation gate` section to tdd.md

- **Test:** AC-1 + the drift-guard tests pass.
- **Implement:** Insert a new `## Live-API validation gate` section into `.claude/rules/tdd.md`, placed after the "Red-Green-Refactor cycle" section and before "Test Structure" (so it reads as a foundational gate, not an afterthought). Section content: ~6 lines covering rule + why + two prior-incident anchors (BTS-115, BTS-170).
- **Files:** `.claude/rules/tdd.md` (modified).
- **Verify:** Tests pass. Read back the section in context — it flows naturally with surrounding text.

### Step 3: Update `/plan` skill prose with risk-language instruction

- **Test:** AC-2 — the `.claude/commands/plan.md` source contains a new instruction that requires risk-language plan steps to enumerate the live validation command.
- **Implement:** Add a new instruction (numbered or bulleted) to `.claude/commands/plan.md`'s Steps section: "When a plan step contains language implying live-API contract uncertainty (`live API`, `exact filter shape`, `may not work`, `verify against live`, `if the live API rejects`, etc.), include an explicit live-validation gate at that step — name the live command to run and require its execution BEFORE the implementation step is considered complete. See `.claude/rules/tdd.md` for the rule."
- **Files:** `.claude/commands/plan.md` (modified).
- **Verify:** Read back the instruction. Confirm it references tdd.md so it doesn't duplicate the rule.

### Step 4: Add self-review flag-list bullet

- **Test:** AC-3 — `.claude/rules/self-review.md`'s "When to Flag" section gains one bullet on live-API validation gaps.
- **Implement:** Add one bullet under the existing "When to Flag" criteria: "A plan-flagged live-API contract risk where the implementer skipped live-validation before commit."
- **Files:** `.claude/rules/self-review.md` (modified).
- **Verify:** Read back the bullet in context.

### Step 5: Hub guide cross-reference

- **Test:** AC-5 — `.ccanvil/guide/core-workflow.md` (or `decision-guide.md`, whichever is the better fit after reading) gains one sentence about the live-API validation gate as part of TDD discipline.
- **Implement:** Add one sentence near existing TDD references. Example: "Plans that flag live-API contract risks must include an explicit live-validation step before commit — see `.claude/rules/tdd.md` for the rule."
- **Files:** `.ccanvil/guide/core-workflow.md` (or `.ccanvil/guide/decision-guide.md`) — modified.
- **Verify:** Read back. Confirm the sentence is brief and doesn't duplicate the rule body.

### Step 6: Idempotency / hub-managed section bracketing

- **Test:** AC-6 — re-running a downstream `ccanvil-sync.sh pull` doesn't double-add the section.
- **Implement:** No code change — verification only. The new tdd.md section is placed above the `<!-- NODE-SPECIFIC-START -->` marker, so it lives in the hub-managed portion. Confirm via `grep -B1 -A20 "Live-API" .claude/rules/tdd.md` that the new section is above the marker, not below.
- **Files:** None — verification only.
- **Verify:** Visual confirmation. Document in commit message.

## Risks

- **Phrasing too narrow.** If the rule's keyword list (`live API`, `exact filter shape`, etc.) is too narrow, future risk-language phrasings won't trigger awareness. Mitigation: the rule's intent — "live-API contract uncertainty" — is the durable concept; the keyword list is illustrative, not exhaustive. The rule prose says "or equivalent phrasings" to keep it open.
- **Phrasing too broad.** If the rule fires on every API mention, it becomes noise. Mitigation: the rule explicitly applies only to plan steps that flag *uncertainty* (verbiage like "may not work", "if the live API rejects", "verify against live"). Plain API usage doesn't qualify.
- **Drift-guard test brittleness.** Asserting on prose content (literal phrase `live-API`) couples the test to specific wording. Mitigation: only two literal-grep assertions, and they target stable anchor tokens (`live-API` and BTS-XXX references) that won't change without a deliberate edit. If the rule wording changes substantially in the future, the test fails loudly — that's a feature.

## Definition of Done

- [ ] All 6 acceptance criteria from spec pass.
- [ ] Drift-guard bats test green.
- [ ] Full suite green.
- [ ] /review run on the substrate diff (rule + skill prose changes affect Claude's behavior; substantive even if narrow).
- [ ] tdd.md, plan.md skill, self-review.md, drift-guard test, and one guide section all updated in a single coherent commit.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
