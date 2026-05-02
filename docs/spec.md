# Feature: /spec --review critic-mode hand-off

> Feature: bts-266-spec-review-critic-mode
> Work: linear:BTS-266
> Created: 1777743393
> Subject: /spec --review critic-mode hand-off
> Status: In Progress

## Summary

Today specs are drafted by Claude and accepted by the operator with no programmatic critic step. BTS-265 added deterministic structural validation (`validate-spec`); this ticket adds the semantic critic gate. New `/spec --review <feature-id>` flag: reads the spec content + validate-spec's JSON envelope, then spawns the `spec-writer` agent in **critic mode** to issue ONE structured finding (BLOCKING or PASS). Closes Layer 1's L1-A (specs-go-unread) and L1-B (Claude-internal handoff) gaps. No new substrate primitive — pure skill flag + agent prose addition. Operator iterates: revise spec → re-run `/spec --review` until PASS.

## Job To Be Done

**When** an operator has drafted a spec via `/spec` and wants a critic pass before activating,
**I want to** run `/spec --review <feature-id>` and get ONE actionable BLOCKING finding (or PASS) from a focused critic agent that reads the spec end-to-end,
**So that** Layer 1 has a programmatic critic gate matching the rigor of Layer 2's drift-guard and Layer 3's diff-vs-manifest — without operator-attention drift.

## Acceptance Criteria

- [ ] **AC-1:** Given a draft spec exists at `docs/specs/<id>.md` (or in Linear-routed Document), When the operator runs `/spec --review <feature-id>`, Then the skill skips the drafting branch and enters critic mode: invokes `validate-spec --feature <id>` to capture the JSON envelope, then spawns the `spec-writer` agent in critic mode with both the spec content and the envelope as inputs.
- [ ] **AC-2 (single finding):** The spec-writer agent in critic mode returns EXACTLY one of: (a) `PASS — no blocking ambiguity found.` (b) a structured BLOCKING finding shaped `{class, line_ref, criterion, why_blocking}` where `class` is one of `ambiguous-criterion`, `untestable-criterion`, `missing-error-path`, `vague-affected-files`, `out-of-scope-leak`, `dependency-not-named`. Multi-finding output is OoS — operator iterates.
- [ ] **AC-3 (consumes validate-spec):** Critic mode's prompt to the agent EXPLICITLY includes the validate-spec envelope (passed as JSON in the system prompt or attached as context). Agent's finding never duplicates a structural drift already surfaced by validate-spec — the agent's job is the SEMANTIC layer (does this spec make sense?), not the structural one.
- [ ] **AC-4 (error: missing spec):** Given `/spec --review <unknown-id>` where the spec doesn't exist, the skill surfaces validate-spec's `ERROR: spec not found` error and exits without spawning the agent.
- [ ] **AC-5 (agent: critic-mode section):** `.claude/agents/spec-writer.md` gains a `## Critic Mode` section that defines: (a) when to enter critic mode (skill passes `MODE=critic`), (b) what inputs to expect (spec content + validate-spec envelope), (c) the single-finding output contract, (d) the 6 finding classes from AC-2, (e) the discipline of "ONE blocking finding per pass — don't bundle".
- [ ] **AC-6 (skill: --review branch):** `.claude/skills/spec/SKILL.md` gains a top-level branch: when first arg is `--review <feature-id>`, skip the work-resolve / draft / stamp / dispatch path and enter the critic-mode invocation. Validate-spec runs first; agent spawns second; report is shaped as `## Critic Finding` (or `## Critic Pass`).
- [ ] **AC-7:** New bats test file `hub/tests/spec-review-flag.bats` covers AC-1's dispatch shape: when invoked with `--review <id>`, the skill's deterministic prefix (validate-spec invocation) runs and emits the JSON envelope. Agent spawn is OoS (can't bats-test agent output).
- [ ] **AC-8:** Live dogfood — run `/spec --review bts-266-spec-review-critic-mode` (this spec) at the end of implementation and confirm the agent returns either PASS or a BLOCKING finding. Document the result in the PR body.

## Affected Files

| File | Change |
|------|--------|
| `.claude/skills/spec/SKILL.md` | Modified — add --review branch (Step 0a) |
| `.claude/agents/spec-writer.md` | Modified — add Critic Mode section |
| `hub/tests/spec-review-flag.bats` | New — dispatch shape coverage |

## Dependencies

- **Requires:** BTS-265 `validate-spec` primitive (shipped — Layer 1 structural envelope is consumed by the critic).
- **Blocked by:** none.

## Out of Scope

- Multi-finding output. ONE BLOCKING per pass. Operator iterates: revise spec → re-run `/spec --review`. This compounds quality without overwhelming the operator with a critique fire-hose.
- Retroactive re-running on completed/archived specs. Critic mode is for in-flight drafts; archived specs are immutable historical record.
- Automatic spec rewriting (i.e., "fix it for me"). The agent surfaces the issue + reasoning; operator decides whether to accept, push back, or scope-down. Mirrors how code reviewers work — they flag, they don't auto-merge.
- Adding a new substrate primitive. This ticket is pure skill flag + agent prose — no new `cmd_*`, no allowlist entry. Layer 1 critic-mode is fundamentally semantic; substrate machinery doesn't help.
- Bats coverage of the agent's actual output quality. Agent behavior is inherently stochastic; bats covers the deterministic dispatch shape (validate-spec runs first; envelope is captured), not the semantic finding.

## Implementation Notes

- Skill flow for `--review <id>`: skip Steps 1-10 (drafting). Run validate-spec, capture envelope. Spawn spec-writer agent with prompt: `MODE=critic\n\nSPEC_PATH: docs/specs/<id>.md\nVALIDATE_SPEC_ENVELOPE: <json>\n\nReturn EXACTLY ONE blocking finding OR the literal "PASS — no blocking ambiguity found.". Finding shape: {class, line_ref, criterion, why_blocking}. Classes: <enumerate>.`
- Agent prose mirrors `code-reviewer.md`'s manifest-aware section structure — start with what the mode is, when it activates, what inputs, what output, what discipline.
- Re-using the existing `spec-writer` agent (rather than creating a new `spec-critic`) keeps the agent registry small and lets the same agent context-switch between draft mode (from `/spec`) and critic mode (from `/spec --review`).
- Live-API risk: NONE. Agent invocation is local Claude reasoning; no external services called.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
