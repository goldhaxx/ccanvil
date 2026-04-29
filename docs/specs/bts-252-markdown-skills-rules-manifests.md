# Feature: Markdown skills + rules manifests

> Feature: bts-252-markdown-skills-rules-manifests
> Work: linear:BTS-252
> Created: 1777482665
> Subject: Markdown skills + rules manifests
> Status: Draft

## Summary

Per `docs/manifest-rollout.md` Session 9 — extend Layer 2 (Self-Describing Systems) coverage to markdown skills + rules. Adds 14 YAML-frontmatter `manifest:` blocks across 8 remaining skills (`ccanvil-pull-globals`, `drift-watchdog`, `idea`, `radar`, `recall`, `ship`, `stasis`, `tdd`) and 6 remaining rules (`code-quality`, `deterministic-first`, `evidence-required-for-captures`, `provider-integration`, `self-review`, `workflow`). Uses the BTS-240 markdown extraction substrate; allowlist 151 → 165. Pure documentation/contract ship — no behavior changes; markers are not required for `.md` paths (per BTS-240 marker-skip).

## Job To Be Done

**When** I'm cold-reading a skill or rule and need to know its purpose, callers, dependencies, side-effects, and failure modes,
**I want to** read the YAML frontmatter `manifest:` block at the top of the file using the same field set as cmd_* primitives,
**So that** every documentation surface in `.claude/skills/` and `.claude/rules/` is self-describing and drift-guard catches regressions when the body's claims drift from the manifest's claims.

## Acceptance Criteria

Each criterion is independently testable. Binary pass/fail.

- [ ] **AC-1:** Each of the 8 skills (`ccanvil-pull-globals`, `drift-watchdog`, `idea`, `radar`, `recall`, `ship`, `stasis`, `tdd`) carries a top-level YAML frontmatter `manifest:` block with all required keys (`purpose`, `input`, `output`, `side-effect`, `failure-mode`, `contract`, `anchor`).
- [ ] **AC-2:** Each of the 6 rules (`code-quality`, `deterministic-first`, `evidence-required-for-captures`, `provider-integration`, `self-review`, `workflow`) carries a top-level YAML frontmatter `manifest:` block with all required keys.
- [ ] **AC-3:** `.ccanvil/manifest-allowlist.txt` adds 14 file-level markdown entries (path-only, no `:fn` suffix) under a new `# BTS-252 — Session 9` section. Total entries 151 → 165.
- [ ] **AC-4:** `bash .ccanvil/scripts/module-manifest.sh validate --json` exits 0 with `coverage.covered == 165`, `coverage.total == 165`, `drift == []`. Bidirectional drift-guard verifies declared callers / depends-on resolve via `_target_body_grep`'s markdown branch (BTS-240).
- [ ] **AC-5:** Every declared `caller:` resolves — for path-form callers, the file exists and contains a word-boundary match for the primitive id or its dispatch verb; for `skill:/<name>` callers, the skill or command file exists and contains the match.
- [ ] **AC-6:** Every declared `depends-on:` resolves via the markdown body grep (post-frontmatter scope). Helpers, scripts, or sub-substrates referenced in the manifest are actually mentioned in the rule/skill body.
- [ ] **AC-7 (Edge):** A skill / rule that declares a phantom caller (e.g., `skill:/nonexistent`) produces `DRIFT: <path> reason=caller-not-found`. Verified by an inline test against any trailing typo before commit; the existing markdown drift-guard tests (`hub/tests/module-manifest-markdown-validate.bats`) cover this generically.
- [ ] **AC-8:** Full bats suite passes (`bash .ccanvil/scripts/bats-report.sh --parallel` reports 1925+ / 0 / total). No new tests introduced — existing markdown drift-guard suite verifies semantic correctness of the new manifests.

## Affected Files

| File | Change |
|------|--------|
| `.claude/skills/ccanvil-pull-globals/SKILL.md` | Modified — frontmatter manifest block added |
| `.claude/skills/drift-watchdog/SKILL.md` | Modified — frontmatter manifest block added |
| `.claude/skills/idea/SKILL.md` | Modified — frontmatter manifest block added |
| `.claude/skills/radar/SKILL.md` | Modified — frontmatter manifest block added |
| `.claude/skills/recall/SKILL.md` | Modified — frontmatter manifest block added |
| `.claude/skills/ship/SKILL.md` | Modified — frontmatter manifest block added |
| `.claude/skills/stasis/SKILL.md` | Modified — frontmatter manifest block added |
| `.claude/skills/tdd/SKILL.md` | Modified — frontmatter manifest block added |
| `.claude/rules/code-quality.md` | Modified — frontmatter manifest block added |
| `.claude/rules/deterministic-first.md` | Modified — frontmatter manifest block added |
| `.claude/rules/evidence-required-for-captures.md` | Modified — frontmatter manifest block added |
| `.claude/rules/provider-integration.md` | Modified — frontmatter manifest block added |
| `.claude/rules/self-review.md` | Modified — frontmatter manifest block added |
| `.claude/rules/workflow.md` | Modified — frontmatter manifest block added |
| `.ccanvil/manifest-allowlist.txt` | Modified — +14 markdown entries (151 → 165) |
| `docs/manifest-rollout.md` | Modified — Inventory `Done` column updated |

## Dependencies

- **Requires:** BTS-239 (manifest substrate), BTS-240 (markdown frontmatter parser + `_target_body_grep` markdown branch)
- **Blocked by:** none

## Out of Scope

- Markdown agents (5) and commands (16) — Session 10
- Layer 3 / `code-reviewer` integration — Session 11
- Modifying skill/rule bodies — frontmatter-only ship
- Adding new markers to skills/rules — markers are not enforced for `.md` paths (BTS-240 design)

## Implementation Notes

- **Frontmatter shape:** existing seeded skill (`spec`) and rule (`tdd`) carry the canonical shape. Read `.claude/skills/spec/SKILL.md` and `.claude/rules/tdd.md` for the field structure. The `name:` and `description:` keys at the top of skills' frontmatter must be preserved; the `manifest:` key is added as a sibling.
- **id field:** for skills, use the skill's directory name (e.g., `recall`, `idea`). For rules, use the file's basename without `.md` (e.g., `code-quality`, `tdd`). The `id` MUST match what the validator's basename fallback would compute.
- **Caller resolution:** declared callers can be path form (e.g., `.claude/commands/foo.md`, `.ccanvil/scripts/docs-check.sh`) or skill form (`skill:/recall`). Path form is preferred for non-skill `.claude/` files (rules, agents). Skill form for skills/commands.
- **Depends-on:** body-scoped grep via `_target_body_grep`'s markdown branch (frontmatter is stripped before grep). Declare deps that the rule/skill body actually mentions by name (script names, helper functions referenced in command examples).
- **Allowlist shape:** path-only entries (no `:fn` suffix). Like Session 8 file-level shell — `id` is derived from basename minus extension.
- **Anchor:** at least one BTS for origin; BTS-252 (manifest seed) as the second anchor for traceability of when the manifest landed.
- **No body changes:** every rule and skill body is unchanged. Only the frontmatter is touched.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
