# Feature: /idea capture flags for templated body sections

> Feature: bts-172-idea-template-flags
> Work: linear:BTS-172
> Created: 1777179996
> Status: In Progress

## Summary

BTS-162 Part 2 (deferred from BTS-162 Part 1's `--parent` flag ship). Original framing called for a `/idea capture-from-context` subcommand that auto-detects the active skill name + cross-ticket family from session context. Auto-detection requires session-context plumbing that doesn't exist yet (no per-session buffer, no skill-name marker emitted by hooks). Proportionate scope: ship the explicit-flag form of the same contract — add `--context <text>`, `--family BTS-A,BTS-B`, `--source-skill <name>` to bare `/idea` capture. When set, the flags prepend templated sections to the body before dispatch. Bare `/idea <text>` (no flags) is unchanged. If a session-context buffer is built later, the same flags get auto-populated transparently.

## Job To Be Done

**When** I'm capturing a series of related tickets during a walk-through (radar, permissions-review, post-incident),
**I want** explicit flags that prepend the recurring boilerplate (active-skill anchor, surfacing context, family cross-refs) to the body,
**So that** I stop hand-typing 80 tokens of boilerplate per capture, and so the cross-references stay consistent across the family rather than drifting via copy-paste.

## Acceptance Criteria

Each criterion is independently testable. Binary pass/fail.

- [ ] **AC-1:** `docs-check.sh idea-template-body --body "the body" --source-skill stasis --context "row 6 of 16" --family BTS-150,BTS-169 BTS-171` (where the trailing positional is project-dir) emits a templated body that contains, in this order: a `Captured during /stasis walk-through.` line, a `Surfaced at row 6 of 16.` line, then a `## Family` section listing each ref as a bullet, then the original body verbatim. Validated by stdout shape match.
- [ ] **AC-2:** When all three flags are absent (`docs-check.sh idea-template-body --body "the body" .`), the script emits the body verbatim with no prepended sections. No-flag form is a passthrough.
- [ ] **AC-3:** When only `--family BTS-A,BTS-B` is set, the output prepends ONLY the `## Family` section. The other two anchor lines are absent. Independently composable.
- [ ] **AC-4:** When `--source-skill` is set but `--context` is not, the output prepends only the `Captured during /<skill> walk-through.` line. Surfacing-context section absent.
- [ ] **AC-5:** Validation: `--family ""` (empty list) exits 2 with `idea-template-body: --family requires a non-empty comma-separated list`. Whitespace-only family value `--family " , "` rejected with the same error.
- [ ] **AC-6:** Validation: `--source-skill ""` rejected with `idea-template-body: --source-skill requires a non-empty value`. `--context ""` rejected analogously.
- [ ] **AC-7:** Skill-prose drift-guard — `.claude/skills/idea/SKILL.md` documents the three flags in the Capture step (Step 0 alongside `--parent`). Drift-guard test asserts the literal flag tokens appear in the prose.
- [ ] **AC-8:** Drift-guard — `cmd_idea_template_body` is registered in the `docs-check.sh` dispatch case. Validated via `grep -q "idea-template-body)" .ccanvil/scripts/docs-check.sh`.

## Affected Files

| File | Change |
|------|--------|
| `.ccanvil/scripts/docs-check.sh` | Modified — add `cmd_idea_template_body` function and dispatch case |
| `.claude/skills/idea/SKILL.md` | Modified — Step 0 documents the three new flags alongside `--parent` |
| `hub/tests/idea-template-flags.bats` | New — AC-1 through AC-8 tests |

## Dependencies

- **Requires:** BTS-162 Part 1 (`--parent` flag, already shipped) for the Step-0 flag-extraction pattern in skill prose.
- **Blocked by:** none.

## Out of Scope

- **Auto-detection of active skill name.** Originally proposed in BTS-162 ticket. Requires hook-emitted session marker (`CLAUDE_ACTIVE_SKILL` env var or similar). When that substrate exists, the skill prose can pre-populate `--source-skill` from the env var without changing the script-level contract. Capture as a follow-up if the friction recurs.
- **Auto-detection of cross-session family.** Same substrate gap as above — no buffer tracking "tickets created in this session." Operator passes `--family` explicitly.
- **`capture-from-context` subcommand.** Folded into bare `/idea` flags. The subcommand framing was a misdirection — without auto-detection there's no value-add over flags-on-/idea.
- **Default boilerplate templates.** The script emits exactly what flags request, no defaults. Skills that want fancier templates (numbered family, section-anchor links) should compose their own bodies and pass them through `--body`.
- **Markdown shape variations.** `## Family` is the chosen heading; flat bullet list is the chosen list shape. Don't expose alternatives via flags. Consistency is the point.

## Implementation Notes

- **Substrate vs skill split.** Templating logic lives in `cmd_idea_template_body` (testable, deterministic). The skill calls the script with the user's flags, captures stdout, then forwards the templated body through the existing capture pipeline (Linear http or local JSONL). Skill prose is thin — flag forwarding only, no string composition.
- **Output shape.** Templated body is exactly:
  ```
  Captured during /<source-skill> walk-through.
  Surfaced at <context>.

  ## Family
  - BTS-A
  - BTS-B

  <original body>
  ```
  Each prepended line is followed by a blank line for markdown rendering. Sections are emitted in the fixed order above; missing flags collapse the corresponding section without leaving stray blank lines.
- **Family parsing.** `--family BTS-A,BTS-B` splits on comma, trims whitespace per item, rejects empty items after split. Output is one bullet per non-empty trimmed item.
- **Validation layer.** All three flags validated at parse time in `cmd_idea_template_body`. Same defense-in-depth pattern as BTS-162's `--parent`.
- **No live-API risk.** Pure shell-logic substrate change + skill-prose update. /review skipped per skip-feedback memory if the diff is purely additive.
- **Skill-prose minimal change.** Step 0 already exists (BTS-162). Extend the flag-extraction list to include `--context`, `--family`, `--source-skill`. Document that when ANY are set, the skill calls `docs-check.sh idea-template-body` to compose the final body before the existing capture flow.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
