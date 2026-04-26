# Implementation Plan: Document safe-markdown rule for Linear-bound idea bodies

> Feature: bts-125-safe-markdown-rule
> Work: linear:BTS-125
> Created: 1777178566
> Spec hash: $(docs-check.sh status | jq -r '.spec.content_hash')
> Based on: docs/spec.md

## Objective

Add a `## Safe-markdown for Linear-bound bodies` section to `.claude/skills/idea/SKILL.md` documenting the observed Linear server-side normalization (bold-around-leading-codespan strips bold) and the avoidance shapes. One drift-guard bats file mirroring BTS-171's pattern. Pure-prose substrate change; /review skip per skip-feedback memory.

## Sequence

### Step 1: Drift-guard tests (RED)

- **Test:** `hub/tests/idea-safe-markdown-rule.bats` with 4 strict-mode assertions:
  - AC-1: SKILL.md has `## Safe-markdown for Linear-bound bodies` heading.
  - AC-2: SKILL.md mentions all three pattern shapes — fail-pattern (`**` followed by backtick), pass-rewrite-1 (codespan dash text), pass-rewrite-2 (bold with backtick later).
  - AC-3: SKILL.md mentions `BTS-125` by name in the new section.
  - AC-4: New section appears ABOVE the `<!-- NODE-SPECIFIC-START -->` marker.
- **Files:** `hub/tests/idea-safe-markdown-rule.bats` (NEW).
- **Verify:** `bats hub/tests/idea-safe-markdown-rule.bats` — all 4 RED.

### Step 2: SKILL.md prose addition (GREEN)

- **Implement:** Insert the new section above `<!-- NODE-SPECIFIC-START -->` in `.claude/skills/idea/SKILL.md`. ~80 words, three short paragraphs:
  1. The trigger (numbered-list-item bold whose content STARTS with a backticked code-span).
  2. Avoidance rewrites: `` `code` — text. `` or `**Text with `code` later.**`.
  3. Cross-link to BTS-125 for repro evidence.
- **Files:** `.claude/skills/idea/SKILL.md`.
- **Verify:** `bats hub/tests/idea-safe-markdown-rule.bats` — all GREEN.

### Step 3: Full-suite verification + commit

- **Test:** `bash .ccanvil/scripts/bats-report.sh --parallel`. 1365 → 1369 (or however many drift-guard assertions land as separate `@test` blocks) green.
- **Implement:** Single commit: `feat(bts-125): document safe-markdown rule for Linear-bound idea bodies`.
- **Verify:** `docs-check.sh validate` aligned; tests green.

## Risks

- **Drift-guard fragility.** Asserting literal pattern strings can break on benign rephrasing. Mitigation: anchor on the most stable substrings (the section heading, the `BTS-125` reference, the literal `**` and backtick in patterns) rather than full sentences.
- **No live-API risk.** No plan step calls a risky API. Live-API gate not triggered.
- **No /review needed.** Pure-prose + drift-guard test. Skip-feedback memory applies.

## Definition of Done

- [ ] All AC-1 through AC-5 pass
- [ ] Existing tests green (1365 → 1369)
- [ ] No type errors (n/a — prose only)
- [ ] /review skipped per pure-prose policy

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
